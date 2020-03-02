# frozen_string_literal: true
require 'byebug'
require 'date'
require 'json'
require 'securerandom'
require 'yaml'

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

def nart_patient_tag(nart_patient)
  name = nart_patient[:person][:names].first
  formatted_name = "#{name&.[](:given_name)} #{name&.[](:family_name)}"

  arv_number = nart_patient[:identifiers].first&.[](:identifier)

  "#{arv_number} - #{formatted_name}"
end

begin
  errors = {}
  total_patients = 0

  EmastercardReader.read_patients.each do |patient|
    patient[:errors] = [] # For logging transformation errors
    nart_patient = Transformers::Patient.transform(patient)

    unless patient[:errors].empty?
      errors[nart_patient_tag(nart_patient)] = patient[:errors]
    end

    Loaders::Patient.load(nart_patient)
    total_patients += 1
  end
ensure
  print "----- Total patients processed: #{total_patients}\n"
  print "----- Total patients with errors: #{errors.size}]n"

  File.open('errors.yaml', 'w') do |fout|
    fout.write("Total patients processed: #{total_patients}\n")
    fout.write("Total patients with errors: #{errors.size}\n")
    fout.write(YAML.dump(errors))
  end
end
