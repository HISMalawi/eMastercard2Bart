# frozen_string_literal: true

require_relative '../logging'

module EMastercardReaders
  module PersonReader
    class << self
      def read_person(sequel, patient)
        LOGGER.debug("Constructing person for eMastercard patient ##{patient[:patient_id]}.")

        person = sequel[:person].select(:gender, :birthdate, :birthdate_estimated)
                                .first(person_id: patient[:patient_id])

        {
          names: read_person_names(sequel, patient),
          addresses: read_person_addresses(sequel, patient),
          attributes: read_person_attributes(sequel, patient),
          relationships: read_person_relationships(sequel, patient),
          gender: person[:gender],
          birthdate: person[:birthdate],
          birthdate_estimated: person[:birthdate_estimated]
        }
      end

      private

      def read_person_names(sequel, patient)
        LOGGER.debug("Reading eMastercard person names for patient ##{patient[:patient_id]}")
        sequel[:person_name].select(:given_name, :family_name, :middle_name)
                            .where(person_id: patient[:patient_id])
                            .to_a
      end

      def read_person_addresses(sequel, patient)
        LOGGER.debug("Reading eMastercard person addresses for patient ##{patient[:patient_id]}")
        addresses = sequel[:person_address].where(person_id: patient[:patient_id])
                                           .select(:city_village)

        addresses.map do |address|
          # eMastercard only saves a location that's sort of a landmark
          { landmark: address[:city_village] }
        end
      end

      def read_person_attributes(_sequel, patient)
        LOGGER.debug("Reading eMastercard person attributes for patient ##{patient[:patient_id]}")
        [{ person_attribute_type: 'Phone number', value: patient[:patient_phone] }]
      end

      def read_person_relationships(_sequel, patient)
        guardian_name = patient[:guardian_name]&.strip
        return [] if guardian_name.nil? || guardian_name.size.zero?

        given_name, family_name = guardian_name.split(/\s+/, 2)

        [
          {
            person_b: {
              names: [{ given_name: given_name, family_name: family_name, middle_name: nil }],
              attributes: [{ person_attribute_type: 'Phone number', value: patient[:guardian_phone] }]
            },
            relationship_type: 'Guardian'
          }
        ]
      end
    end
  end
end
