# frozen_string_literal: true

require_relative '../databases'
require_relative './nart'
require_relative './emastercard'

require 'byebug'
require 'csv'
require 'logger'
require 'sequel'
require 'yaml'

EMASTERCARD_ARV_NUMBER_ID = 4
PATIENTS_SAMPLE_SIZE = 25 # Percentage of the entire population

INDICATORS = %w[
  outcome
  ever_taken_arvs
  initial_tb_status
  pregnant_or_breastfeeding
  who_stage
  kaposis_sarcoma
  hiv_related_diseases
  side_effects
  tb_status
  arvs_dispensed
  cpt_dispensed
  viral_load_result
  viral_load_result_symbol
  next_appointment_date
  art_start_date
  art_regimen
].freeze

LOGGER = Logger.new(STDOUT)
LOGGER.level = Logger::DEBUG

def main
  CSV.open('stats.csv', 'wb') do |csv|
    csv << ['Indicator', 'ARV Number', 'date', 'eMastercard', 'NART']

    matches = 0
    failures = 0

    fetch_indicator_random_sample(:outcome).each do |row|
      csv << row

      if row[-2].casecmp?(row[-1])
        matches += 1
      else
        failures += 1
      end
    end

    csv << ['Matching:', matches]
    csv << ['Not matching:', failures]
    csv << ['Accuracy:', matches.to_f / (matches + failures)]
  end
end

def fetch_indicator_random_sample(indicator, sample_size: 6000)
  Enumerator.new do |enum|
    random_arv_numbers(emastercard_db, sample_size).each do |identifier|
      patient_id, arv_number = identifier

      iemastercard, date = Emastercard.read_indicator(emastercard_db, indicator, patient_id)
      next unless iemastercard

      inart = Nart.read_indicator(nart_db, indicator, Nart.find_patient_id(nart_db, arv_number), date)

      enum.yield([indicator, arv_number, date, iemastercard.upcase, inart&.upcase])
    end
  end
end

# Returns a list of indicators to be processed
def indicators
  INDICATORS
end

# Selects random ARV numbers from the emastercard database
def random_arv_numbers(emastercard_db, count)
  emastercard_db[:patient_identifier]
    .order(Sequel.lit('RAND()'))
    .limit(count)
    .select(:patient_id, :identifier)
    .map(%i[patient_id identifier])
end

main
