# frozen_string_literal: true

require 'byebug'
require 'logger'
require 'sequel'
require 'yaml'

module EmastercardDb
  class << self
    def find_observation(person_id, concept_id, encounter_type = nil)
      encounter_type ||= Emastercard::Encounters::ART_REGISTRATION

      from_table[:obs].join(:encounter, encounter_id: :encounter_id)
                      .first(encounter_type: encounter_type,
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
        .order('obs.date_created DESC')
        .first
    end
  end

  def self.from_table
    LOGGER.debug('Retrieving eMastercard database instance...')
    return @from_table if @from_table

    LOGGER.debug('Loading eMastercard database configuration...')
    config = CONFIG['emastercard']
    engine = config['engine'] || 'mysql2'
    username = CGI.escape(config['username'])
    password = CGI.escape(config['password'])
    host = config['host'] || 'localhost'
    port = config['port'] || 3306
    database = config['database']

    LOGGER.debug('Connecting to eMastercard database...')
    @from_table = Sequel.connect("#{engine}://#{username}:#{password}@#{host}:#{port}/#{database}")
    @from_table.loggers << Logger.new(STDOUT)
    @from_table
  end
end
