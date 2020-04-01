# frozen_string_literal: true

require_relative '../config'
require_relative '../databases'
require_relative '../emastercard_constants'
require_relative '../logging'

require 'csv'

SITE_PREFIX = config['site_prefix'].downcase

def main
  CSV.open("tmp/#{SITE_PREFIX}-patients-with-blank-outcomes.csv", 'wb') do |csv|
    csv << ['ARV Number', 'Name']

    patients_with_blank_outcomes.each do |patient|
      csv << patient
    end
  end
end

def patients_with_blank_outcomes
  emastercard_db[:obs].join(:patient_identifier, patient_id: :person_id)
                      .join(:person_name, person_id: :patient_id)
                      .where(concept_id: Emastercard::Concepts::OUTCOME)
                      .where(Sequel.lit("value_text LIKE '%Blank%'"))
                      .select(Sequel.lit('identifier, COALESCE(given_name, " ", family_name) AS name'))
                      .group(:identifier, :name)
                      .map(%i[identifier name])
end

main
