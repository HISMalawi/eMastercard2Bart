# frozen_string_literal: true

require_relative '../config'
require_relative '../databases'
require_relative '../nart_constants'

require 'csv'

SITE_PREFIX = config['site_prefix'].downcase

def main
  CSV.open("tmp/#{SITE_PREFIX}-patients-migrated.csv", 'wb') do |csv|
    csv << ['ARV Number', 'Patient Name']

    all_nart_patients.each { |patient| csv << patient }
  end
end

def all_nart_patients
  nart_db[:patient].join(:person_name, person_id: :patient_id)
                   .left_join(:patient_identifier, patient_id: :person_id)
                   .where(identifier_type: Nart::PatientIdentifierTypes::ARV_NUMBER)
                   .order(:identifier)
                   .select(Sequel.lit('identifier, CONCAT(given_name, " ", family_name) AS name'))
                   .map(%i[identifier name])
end

main
