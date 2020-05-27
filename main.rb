# frozen_string_literal: true
require 'byebug'
require 'csv'
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

MIGRATION_ERRORS_FILE = "tmp/#{SITE_PREFIX.downcase}-migration-errors.yaml"

def total_patients_read_on_last_run
  return 0 unless File.exist?(MIGRATION_ERRORS_FILE)

  total_patients = File.open(MIGRATION_ERRORS_FILE) do |fin|
    YAML.safe_load(fin.readline)['total_patients_processed']
  end

  total_patients || 0
end

def errors_on_last_run
  return {} unless File.exist?(MIGRATION_ERRORS_FILE)

  errors = File.open(MIGRATION_ERRORS_FILE) do |fin|
    3.times { fin.readline } # Errors start on fourth line

    YAML.safe_load(fin)
  end

  errors || {}
end

def save_errors(total_patients, patients_with_errors)
  print "----- Total patients processed: #{total_patients}\n"
  print "----- Total patients with errors: #{patients_with_errors.size}\n"

  FileUtils.mkdir(MIGRATION_ERRORS_FILE) unless File.exist?('tmp')

  File.open(MIGRATION_ERRORS_FILE, 'w') do |fout|
    fout.write("total_patients_processed: #{total_patients}\n")
    fout.write("total_patients_with_errors: #{patients_with_errors.size}\n")
    fout.write(YAML.dump(patients_with_errors))
  end
end

def save_site_prefix
  site_prefix = NartDb.from_table[:global_property]
                      .where(property: 'site_prefix')
                      .first
  return if site_prefix

  NartDb.into_table[:global_property]
        .insert(uuid: SecureRandom.uuid, property: 'site_prefix', property_value: SITE_PREFIX)
end

def retro_date(date)
  current_time = DateTime.now.strftime('%H:%M:%S.%L')
  date = Date.strptime(date.to_s, '%Y-%m-%d') # Not sure if date is a string or a date
  DateTime.strptime(date.strftime("%Y-%m-%d #{current_time}"), '%Y-%m-%d %H:%M:%S.%L')
end

begin
  errors = errors_on_last_run
  total_patients = total_patients_read_on_last_run
  lock = Mutex.new

  save_site_prefix

  Parallel.each(EmastercardReader.read_patients(from: total_patients), in_threads: 8) do |patient|
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
  save_errors(total_patients, errors)
end
