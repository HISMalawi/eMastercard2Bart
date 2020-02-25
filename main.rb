# frozen_string_literal: true
require 'byebug'
require 'json'

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

if CONFIG['site_prefix'].nil? || CONFIG['site_prefix'].empty?
  raise 'site_prefix not set in `config.yml`'
end

EmastercardReader.read_patients.each do |patient|
  nart_patient = Transformers::Patient.transform(patient)
  Loaders::Patient.load(nart_patient)
end
