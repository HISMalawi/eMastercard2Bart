# frozen_string_literal: true

# Scales an eMastercard database extracting ART patients with their
# associated encounters, observations, and other metadata like
# patient_identifiers.

require_relative 'patient_identifiers'
require_relative 'person'
require_relative 'encounters'
require_relative 'patient_program'

module Transformers
  module Patient
    # Constructs an OpenMRS-ish patient structure from an eMastercard patient row.
    def self.transform(emastercard_patient)
      visits = EmastercardReader.read_visits(emastercard_patient[:patient_id]).to_a

      LOGGER.debug("Transforming eMastercard patient ##{emastercard_patient['patient_id']}...")
      person = Person.transform(emastercard_patient)
      encounters = Encounters.transform(emastercard_patient, visits, person)

      {
        person: person,
        encounters: encounters,
        programs: [PatientProgram.transform(emastercard_patient, visits, encounters)].compact,
        identifiers: PatientIdentifiers.transform(emastercard_patient)
      }
    end
  end
end
