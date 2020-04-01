# frozen_string_literal: true

require_relative '../config'
require_relative '../databases'
require_relative '../emastercard_constants'
require_relative '../logging'

require 'csv'

SITE_PREFIX = config['site_prefix']

def main
  CSV.open("tmp/#{SITE_PREFIX.downcase}-patients-without-visits.csv", 'wb') do |csv|
    csv << ['ARV Number', 'Name']
    patients_without_visits.each do |patient|
      csv << patient
    end
  end
end

def patients_with_visits
  emastercard_db[:obs].join(:encounter, encounter_id: :encounter_id)
                      .where(encounter_type: Emastercard::Encounters::ART_VISIT)
                      .group(:person_id)
                      .select(:person_id)
end

def patients_without_visits
  emastercard_db[:person_name].left_join(:patient_identifier, patient_id: :person_id)
                              .exclude(person_id: patients_with_visits)
                              .select(Sequel.lit("identifier, CONCAT(given_name, ' ', family_name) AS name"))
                              .group(:identifier, :name)
                              .map(%i[identifier name])
end

main
