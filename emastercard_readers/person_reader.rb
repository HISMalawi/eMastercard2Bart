# frozen_string_literal: true

require_relative '../logging'

module EMastercardReaders
  module PersonReader
    class << self
      def read_person(mysqlclient, emastercard_patient)
        LOGGER.debug("Constructing person for eMastercard patient ##{emastercard_patient['patient_id']}.")
        patient_id = mysqlclient.escape(emastercard_patient['patient_id'])
        person = mysqlclient.query("SELECT * FROM person WHERE person_id = #{patient_id}").first

        {
          names: read_person_names(mysqlclient, emastercard_patient),
          addresses: read_person_addresses(mysqlclient, emastercard_patient),
          attributes: read_person_attributes(mysqlclient, emastercard_patient),
          relationships: read_person_relationships(mysqlclient, emastercard_patient),
          gender: person['gender'],
          birthdate: person['birthdate'],
          birthdate_estimated: person['birthdate_estimated']
        }
      end

      private

      def read_person_names(mysqlclient, patient_id)
        LOGGER.debug("Reading eMastercard person names for patient ##{patient_id}")
        results = mysqlclient.query("SELECT * FROM person_name WHERE person_id = #{patient_id}")
        results.collect do |result|
          {
            given_name: result['given_name'],
            family_name: result['family_name'],
            middle_name: result['middle_name']
          }
        end
      end

      def read_person_addresses(mysqlclient, patient_id)
        LOGGER.debug("Reading eMastercard person addresses for patient ##{patient_id}")
        results = mysqlclient.query("SELECT * FROM person_address WHERE person_id = #{patient_id}")
        results.collect do |result|
          # eMastercard only saves a location that's sort of a landmark
          { landmark: result['city_village'] }
        end
      end

      def read_person_attributes(_mysqlclient, emastercard_patient)
        LOGGER.debug("Reading eMastercard person attributes for patient ##{emastercard_patient['patient_id']}")
        [
          {
            person_attribute_type: 'Phone number',
            value: emastercard_patient['patient_phone']
          }
        ]
      end

      def read_person_relationships(_mysqlclient, emastercard_patient)
        guardian_name = emastercard_patient['guardian_name']&.strip
        return nil if guardian_name.nil? || guardian_name.size.zero?

        given_name, family_name = guardian_name.split(/\s+/, 2)

        [
          {
            person_b: {
              names: [{ given_name: given_name, family_name: family_name, middle_name: nil }],
              attributes: [{person_attribute_type: 'Phone number',
                            value: emastercard_patient['guardian_phone']}]
            },
            relationship_type: 'Guardian'
          }
        ]
      end
    end
  end
end
