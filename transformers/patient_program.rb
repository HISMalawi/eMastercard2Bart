
# frozen_string_literal: true
module Transformers
  module PatientProgram
    def self.transform(patient, visits)
      outcomes = find_patient_outcomes(patient[:patient_id])
      states = transform_outcomes_to_nart_states(patient, outcomes)
      date_enrolled = visits.first&.[](:encounter_datetime) || states.first&.[](:start_date)

      {
        program_id: Nart::Programs::HIV_PROGRAM,
        date_enrolled: date_enrolled,
        states: states
      }
    end

    def self.transform_outcomes_to_nart_states(patient, outcomes)
      outcomes.each_with_object([]) do |outcome, states|
        outcome_date, outcome_name = outcome
        state_id = outcome_name_to_nart_state_id(outcome_name)
        unless state_id
          patient[:errors] << "Invalid outcome '#{outcome_name}' on #{outcome_date}"
          next
        end

        if states.empty?
          states << { state: state_id, start_date: outcome_date, end_date: nil }
        elsif states.last[:state] == state_id
          states.last[:end_date] = outcome_date
        else
          states.last[:end_date] = outcome_date
          states << { state: state_id, start_date: outcome_date, end_date: nil }
        end
      end
    end

    def self.outcome_name_to_nart_state_id(name)
      case name.upcase
      when 'D' then Nart::PatientStates::DIED
      when 'TO' then Nart::PatientStates::TRANSFERRED_OUT
      when 'STOP' then Nart::PatientStates::TREATMENT_STOPPED
      when 'DEF' then Nart::PatientStates::DEFAULTED
      when 'OT' then Nart::PatientStates::ON_TREATMENT
      when 'PT' then Nart::PatientStates::PRE_ART
      end
    end

    def self.find_patient_outcomes(patient_id)
      implicit_outcomes = find_patient_implicit_outcomes(patient_id)
      explicit_outcomes = find_patient_explicit_outcomes(patient_id)

      (implicit_outcomes + explicit_outcomes).sort_by { |date, _| date }
    end

    # Returns outcomes that are inferred from various conditions a patient
    # is under (eg on treatment)
    def self.find_patient_implicit_outcomes(patient_id)
      on_treatment_outcomes = EmastercardDb.from_table[:obs]
                                           .join(:encounter, encounter_id: :encounter_id)
                                           .where(person_id: patient_id,
                                                  concept_id: Emastercard::Concepts::ARVS_DISPENSED,
                                                  Sequel[:obs][:voided] => 0,
                                                  Sequel[:encounter][:encounter_type] => Emastercard::Encounters::ART_VISIT)
                                           .exclude(value_text: nil, value_numeric: nil)
                                           .order(:encounter_datetime)
                                           .select(:encounter_datetime)
                                           .map { |observation| [observation[:encounter_datetime], 'OT'] }

      initial_treatment_date = on_treatment_outcomes.first&.[](0) || DateTime.now

      pre_art_outcome_date = EmastercardDb.from_table[:obs]
                                          .join(:encounter, encounter_id: :encounter_id)
                                          .where(person_id: patient_id,
                                                 concept_id: Emastercard::Concepts::CPT_DISPENSED,
                                                 Sequel[:obs][:voided] => 0,
                                                 Sequel[:encounter][:encounter_type] => Emastercard::Encounters::ART_VISIT)
                                          .where { Sequel[:encounter][:encounter_datetime] < initial_treatment_date }
                                          .exclude(value_text: nil, value_numeric: nil)
                                          .order(:encounter_datetime)
                                          .first
                                          &.[](:encounter_datetime)

      if pre_art_outcome_date
        on_treatment_outcomes.insert(0, [pre_art_outcome_date, 'PT'])
      end

      on_treatment_outcomes
    end

    # Returns outcomes that are explicitly set in eMastercard.
    def self.find_patient_explicit_outcomes(patient_id)
      EmastercardDb.from_table[:obs]
                   .join(:encounter, encounter_id: :encounter_id)
                   .where(person_id: patient_id,
                          concept_id: Emastercard::Concepts::OUTCOME,
                          Sequel[:obs][:voided] => 0)
                   .exclude(value_text: nil, value_numeric: nil)
                   .order(:encounter_datetime)
                   .map(%i[encounter_datetime value_text])
    end
  end
end
