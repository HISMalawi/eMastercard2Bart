# frozen_string_literal: true

require 'byebug'
require 'logger'
require 'sequel'
require 'yaml'

module EmastercardDbUtils
  def find_observation(person_id, concept_id)
    sequel[:obs].join(:encounter, encounter_id: :encounter_id)
                .first(encounter_type: Emastercard::Encounters::ART_VISIT,
                       concept_id: concept_id,
                       person_id: person_id)
  end

  def find_observation_by_date(person_id, concept_id, date)
    find_all_observations_by_date(person_id, concept_id, date).first
  end

  def find_all_observations(person_id, concept_id)
    sequel[:obs].join(:encounter, encounter_id: :encounter_id)
                .where(encounter_type: Emastercard::Encounters::ART_VISIT,
                       concept_id: concept_id,
                       person_id: person_id)
  end

  def find_all_observations_by_date(person_id, concept_id, date)
    day_start = date.strftime('%Y-%m-%d 00:00:00')
    day_end = date.strftime('%Y-%m-%d 23:59:59')

    find_all_observations(person_id, concept_id).where(obs_datetime: day_start..day_end)
  end

  def find_all_observations_by_encounter(person_id, concept_id, encounter_type_id)
    sequel[:obs].join(:encounter, encounter_id: :encounter_id)
                .where('encounter.encounter_type' => encounter_type_id,
                       concept_id: concept_id,
                       person_id: person_id)
  end

  def find_observation_by_encounter(person_id, concept_id, encounter_type_id)
    find_all_observations_by_encounter(person_id, concept_id, encounter_type_id)
      .order(:encounter_datetime)
      .last
  end

  def sequel
    return @sequel if @sequel

    config = File.open("#{__dir__}/config.yaml") do |config_file|
      YAML.safe_load(config_file)['emastercard']
    end

    engine = config['engine'] || 'mysql2'
    username = config['username']
    password = config['password']
    host = config['host'] || 'localhost'
    port = config['port'] || 3306
    database = config['database']

    @sequel = Sequel.connect("#{engine}://#{username}:#{password}@#{host}:#{port}/#{database}")
    @sequel.loggers << Logger.new(STDOUT)
    @sequel
  end
end
