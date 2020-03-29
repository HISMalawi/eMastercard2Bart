# frozen_string_literal: true
require 'byebug'
require 'date'
require 'json'
require 'parallel'
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

def total_patients_read_on_last_run
  return 0 unless File.exist?('errors.yaml')

  File.open('errors.yaml') { |fin| YAML.safe_load(fin.readline)['total_patients_processed'] } || 0
end

def errors_on_last_run
  return {} unless File.exist?('errors.yaml')

  errors = File.open('errors.yaml') do |fin|
    3.times { fin.readline } # Errors start on fourth line

    YAML.safe_load(fin)
  end

  errors || {}
end

begin
  errors = errors_on_last_run
  total_patients = total_patients_read_on_last_run
  lock = Mutex.new

  patients = EmastercardReader.read_patients(from: total_patients)

  site_prefix = NartDb.from_table[:global_property]
                      .where(property: 'site_prefix')
                      .first
  unless site_prefix
    NartDb.into_table[:global_property]
          .insert(uuid: SecureRandom.uuid, property: 'site_prefix', property_value: SITE_PREFIX)
  end

  Parallel.each(patients, in_threads: 8) do |patient|
    patient[:errors] = [] # For logging transformation errors
    nart_patient = Transformers::Patient.transform(patient)

    unless patient[:errors].empty?
      lock.synchronize do
        errors[nart_patient_tag(nart_patient)] = patient[:errors]
      end
    end

    NartDb.into_table.transaction do
      Loaders::Patient.load(nart_patient)

      lock.synchronize do
        total_patients += 1
      end
    end

    # raise Parallel::Break if total_patients >= 750
  end
ensure
  print "----- Total patients processed: #{total_patients}\n"
  print "----- Total patients with errors: #{errors.size}\n"

  FileUtils.mkdir('tmp') unless File.exist?('tmp')

  File.open('tmp/errors.yaml', 'w') do |fout|
    fout.write("total_patients_processed: #{total_patients}\n")
    fout.write("total_patients_with_errors: #{errors.size}\n")
    fout.write(YAML.dump(errors))
  end
end
