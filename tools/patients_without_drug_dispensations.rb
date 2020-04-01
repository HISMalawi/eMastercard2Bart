# frozen_string_literal: true

require_relative '../config'
require_relative '../databases'
require_relative '../nart_constants'

require 'csv'

def patients_with_drug_dispensations
  nart_db[:obs].join(:encounter, encounter_id: :encounter_id)
               .where(encounter_type: Nart::Encounters::DISPENSING,
                      concept_id: Nart::Concepts::AMOUNT_DISPENSED)
               .exclude(value_numeric: nil)
               .group(:patient_id)
               .select(:patient_id)
end

def patients_without_drug_dispensations
  nart_db[:patient].join(:person_name, person_id: :patient_id)
                   .left_join(:patient_identifier, patient_id: :person_id)
                   .where(identifier_type: Nart::PatientIdentifierTypes::ARV_NUMBER)
                   .exclude(person_id: patients_with_drug_dispensations)
                   .order(:identifier)
                   .group(:person_id)
                   .select(Sequel.lit('patient.patient_id, identifier, CONCAT(given_name, " ", family_name) AS name'))
                   .map(%i[identifier name])
end

SITE_PREFIX = config['site_prefix'].downcase

def main
  CSV.open("tmp/#{SITE_PREFIX}-patients-without-dispensations.csv", 'wb') do |csv|
    csv << ['ARV Number', 'Patient Name']

    patients_without_drug_dispensations.each { |patient| csv << patient }
  end
end

main
