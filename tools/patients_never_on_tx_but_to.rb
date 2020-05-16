# frozen_string_literal: true

require 'parallel'
require 'securerandom'

require_relative '../databases'
require_relative '../config'
require_relative '../nart_db' # Required by loader module
require_relative '../nart_constants'
require_relative '../loaders/patient'

CONFIG = config
EMR_USER_ID = config['emr_user_id']
EMR_LOCATION_ID = config['emr_location_id']

# Retrieves all patients who have never been on treatment but have been transferred out
def patients_never_on_tx_but_to
  nart_db[:patient_state].select(Sequel.lit('patient_program.patient_id AS patient_id,
                                             patient_program.patient_program_id AS patient_program_id,
                                             patient_state.start_date AS start_date'))
                         .join(:patient_program, patient_program_id: :patient_program_id)
                         .exclude(Sequel[:patient_program][:patient_id] => patients_ever_on_tx)
                         .where(state: Nart::PatientStates::TRANSFERRED_OUT)
                         .group(Sequel[:patient_program][:patient_id])
end

def patients_ever_on_tx
  nart_db[:patient_state].select(Sequel[:patient_program][:patient_id])
                         .join(:patient_program, patient_program_id: :patient_program_id)
                         .where(state: Nart::PatientStates::ON_TREATMENT)
                         .group(Sequel[:patient_program][:patient_id])
end

def create_dispensation(patient_id, date)
  treatment = create_treatment_encounter(date)
  dispensation = create_dispensation_encounter(date)
  Loaders::Patient.load_encounters(patient_id, [treatment, dispensation])
end

def create_treatment_encounter(date)
  {
    encounter_type_id: Nart::Encounters::TREATMENT,
    encounter_datetime: date,
    observations: [
      {
        concept_id: Nart::Concepts::ARV_REGIMEN,
        obs_datetime: date,
        value_text: 'Unknown',
        comments: 'This patient had no visit data except a TO state'
      },
      {
        concept_id: Nart::Concepts::DATA_MIGRATION_NOTES,
        obs_datetime: date,
        value_text: <<~NOTES
          This patient had no visit data except a transferred out state.
          The patient was assigned a placeholder dispensation in order
          for the patient to appear on the cohort report (which only
          includes patients that have ever been treatment).
        NOTES
      }
    ],
    orders: [
      {
        order_type_id: Nart::Orders::DRUG_ORDER,
        concept_id: Nart::Concepts::UNKNOWN_ARV,
        start_date: date,
        auto_expire_date: date,
        drug_order: {
          drug_inventory_id: Nart::Drugs::UNKNOWN_ARV,
          equivalent_daily_dose: 1,
          quantity: 1
        }
      }
    ]
  }
end

def create_dispensation_encounter(date)
  {
    encounter_type_id: Nart::Encounters::DISPENSING,
    encounter_datetime: date,
    observations: [
      {
        concept_id: Nart::Concepts::AMOUNT_DISPENSED,
        obs_datetime: date,
        value_drug: Nart::Drugs::UNKNOWN_ARV,
        value_numeric: 1,
        comments: 'This patient had no visit data except a TO state'
      }
    ]
  }
end

def patient_date_enrolled(patient_id)
  nart_db[:obs].where(patient_id: patient_id, concept_id: Nart::Concepts::DATE_ANTIRETROVIRALS_STARTED)
               .select(:obs_datetime)
               .first
               &.[](:obs_datetime)
end

def mark_patient_as_on_treatment(patient_program_id, date)
  state = { state: Nart::PatientStates::ON_TREATMENT, start_date: date, end_date: date }  
  Loaders::Patient.load_patient_states(patient_program_id, [state])
end

def main
  # Eagerly evaluate query to ensure data is available for parallelization
  patients = patients_never_on_tx_but_to.all

  nart_db.transaction do
    Parallel.each(patients, in_threads: 4) do |patient|
      # TODO: Dump patients to a CSV possibly...
      patient_id = patient[:patient_id]
      # date = patient[:start_date]
      patient_program_id = patient[:patient_program_id]

      date_enrolled = patient_date_enrolled(patient_id)
      next unless date_enrolled

      create_dispensation(patient_id, date_enrolled)
      mark_patient_as_on_treatment(patient_program_id, date_enrolled)
    end
  end
end

main
