# frozen_string_literal: true

require_relative '../config'
require_relative '../databases'
require_relative '../emastercard_constants'

require 'csv'

def patients_with_an_outcome
  emastercard_db[:obs].join(:encounter, encounter_id: :encounter_id)
                      .left_join(:patient_identifier, patient_id: :patient_id)
                      .join(:person_name, person_id: :patient_id)
                      .where(encounter_type: Emastercard::Encounters::ART_VISIT,
                             concept_id: Emastercard::Concepts::OUTCOME)
                      .exclude(value_text: nil)
                      .group(Sequel[:encounter][:patient_id])
                      .select(Sequel.lit('encounter.patient_id, identifier, CONCAT(given_name, " ", family_name) AS name'))
                      .map(%i[patient_id identifier name])
end

def patient_first_visit(patient_id)
  emastercard_db[:encounter].join(:obs, encounter_id: :encounter_id)
                            .where(patient_id: patient_id,
                                   encounter_type: Emastercard::Encounters::ART_VISIT)
                            .exclude(value_text: nil, value_numeric: nil, value_datetime: nil)
                            .order(:encounter_datetime)
                            .group(:encounter_datetime)
                            .select(:encounter_datetime)
                            .get(:encounter_datetime)
end

def patients_with_an_outcome_on_first_visit
  patients_with_an_outcome.each_with_object([]) do |patient, filtered_patients|
    patient_id = patient[0]

    first_visit_date = patient_first_visit(patient_id)
    next unless first_visit_date

    outcome = emastercard_db[:obs].join(:encounter, encounter_id: :encounter_id)
                                  .where(encounter_datetime: first_visit_date,
                                         patient_id: patient_id,
                                         concept_id: Emastercard::Concepts::OUTCOME)
                                  .exclude(value_text: nil)
                                  .first

    next unless outcome

    filtered_patients << [*patient, outcome[:value_text], first_visit_date]
  end
end

SITE_PREFIX = config['site_prefix'].downcase

def main
  CSV.open("tmp/#{SITE_PREFIX}-patients-with-outcome-on-first-visit.csv", 'wb') do |csv|
    csv << ['ARV Number', 'Patient Name', 'Outcome', 'Outcome Date']

    patients_with_an_outcome_on_first_visit
      .sort_by { |patient| patient[1] }
      .each { |patient| csv << patient[1..-1] }
  end
end

main
