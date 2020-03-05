# frozen_string_literal: true

module EmastercardReader
  class << self
    # Reads all patients from the database and returns an Enumerator.
    def read_patients(from: 0, batch_size: 1000)
      LOGGER.info("Reading patients from eMastercard db starting at #{from} in batches of #{batch_size}...")
      offset = from

      Enumerator.new do |enum|
        loop do
          LOGGER.info("Reading eMastercard patients from offset #{offset}...")
          results = EmastercardDb.from_table[:patient]
                                 .offset(offset)
                                 .limit(batch_size)
                                 .all
          break if results.size.zero?

          results.each { |result| enum.yield(result) }

          offset += batch_size
        end
      end
    end

    def read_visits(patient_id)
      EmastercardDb.from_table[:visit_outcome_event]
                   .where(event_type: 'Clinical Visit', person_id: patient_id)
                   .order(:encounter_datetime)
    end
  end
end
