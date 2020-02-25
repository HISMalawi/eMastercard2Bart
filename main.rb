# frozen_string_literal: true
require 'byebug'
require 'date'
require 'json'
require 'securerandom'

require_relative 'emastercard_constants'
require_relative 'emastercard_db'
require_relative 'emastercard_reader'
require_relative 'logging'
require_relative 'nart_constants'
require_relative 'nart_db'

require_relative 'loaders/patient'
require_relative 'transformers/patient'

CONFIG = File.open("#{__dir__}/config.yaml") do |config_file|
  YAML.safe_load(config_file)
end

def check_config_option(option)
  return CONFIG[option] if CONFIG[option]

  raise "`#{option}` not set in 'config.yml'"
end

SITE_PREFIX = check_config_option('site_prefix')
EMR_USER_ID = check_config_option('emr_user_id')
EMR_LOCATION_ID = check_config_option('emr_location_id')

EmastercardReader.read_patients.each do |patient|
  nart_patient = Transformers::Patient.transform(patient)
  Loaders::Patient.load(nart_patient)
end
