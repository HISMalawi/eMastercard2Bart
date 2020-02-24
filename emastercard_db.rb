# frozen_string_literal: true

require 'byebug'
require 'logger'
require 'sequel'
require 'yaml'

module EmastercardDb
  class << self
    def find_observation(person_id, concept_id)
      from_table[:obs].join(:encounter, encounter_id: :encounter_id)
                      .first(encounter_type: Emastercard::Encounters::ART_VISIT,
                             concept_id: concept_id,
                             person_id: person_id)
    end

    def find_observation_by_date(person_id, concept_id, date)
      find_all_observations_by_date(person_id, concept_id, date).first
    end

    def find_all_observations(person_id, concept_id)
      from_table[:obs].join(:encounter, encounter_id: :encounter_id)
                      .where(encounter_type: Emastercard::Encounters::ART_VISIT,
                             concept_id: concept_id,
                             person_id: person_id)
    end

    def find_all_observations_by_date(person_id, concept_id, date)
      day_start = date.strftime('%Y-%m-%d 00:00:00')
      day_end = date.strftime('%Y-%m-%d 23:59:59')

      find_all_observations(person_id, concept_id)
        .where(encounter_datetime: day_start..day_end)
    end

    def find_all_observations_by_encounter(person_id, concept_id, encounter_type_id)
      from_table[:obs].join(:encounter, encounter_id: :encounter_id)
                      .where(Sequel[:encounter][:encounter_type] => encounter_type_id,
                             concept_id: concept_id,
                             person_id: person_id)
    end

    def find_observation_by_encounter(person_id, concept_id, encounter_type_id)
      find_all_observations_by_encounter(person_id, concept_id, encounter_type_id)
        .order(:encounter_datetime)
        .last
    end

    def from_table
      return @from_table if @from_table

      config = File.open("#{__dir__}/config.yaml") do |config_file|
        YAML.safe_load(config_file)['emastercard']
      end

      engine = config['engine'] || 'mysql2'
      username = config['username']
      password = config['password']
      host = config['host'] || 'localhost'
      port = config['port'] || 3306
      database = config['database']

      @from_table = Sequel.connect("#{engine}://#{username}:#{password}@#{host}:#{port}/#{database}")
      @from_table.loggers << Logger.new(STDOUT)
      @from_table
    end
  end
end
