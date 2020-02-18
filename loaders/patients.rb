# frozen_string_literal: true

# Scales an eMastercard database extracting ART patients with their
# associated encounters, observations, and other metadata like
# patient_identifiers.

require 'mysql2'

require_relative '../logging'
require_relative 'person'
require_relative 'encounters'

module Loaders
  module Patients
    class << self
      include EmastercardDbUtils

      # Reads all patients from the database
      def load(batch_size: 1000)
        LOGGER.info("Reading patients from eMastercard db in batches of #{batch_size}...")
        offset = 0

        Enumerator.new do |enum|
          loop do
            LOGGER.info("Reading eMastercard patients from offset #{offset}...")
            results = sequel[:patient].offset(offset).limit(batch_size).all
            break if results.size.zero?

            results.each do |result|
              patient = construct_patient_from_mysql_result(result)
              enum.yield(patient)
            end

            offset += batch_size
          end
        end
      end

      private

      # Constructs an OpenMRS-ish patient structure from an eMastercard patient row.
      def construct_patient_from_mysql_result(result)
        LOGGER.debug("Constructing eMastercard patient ##{result['patient_id']}...")
        {
          person: Person.load(result),
          encounters: Encounters.load(result),
          # states: read_patient_states(sequel, result),
          # programs: read_patient_programs(sequel, result),
          # identifiers: read_patient_identifiers(sequel, result)
        }
      end
    end
  end
end
