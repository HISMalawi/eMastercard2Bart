# frozen_string_literal: true

require_relative '../logging'
require_relative '../emastercard_db_utils'

module Transformers
  module Person
    class << self
      include EmastercardDbUtils

      def transform(patient)
        LOGGER.debug("Constructing person for eMastercard patient ##{patient[:patient_id]}.")

        person = sequel[:person].select(:gender, :birthdate, :birthdate_estimated)
                                .first(person_id: patient[:patient_id])

        {
          names: read_person_names(patient),
          attributes: read_person_attributes(patient),
          relationships: read_person_relationships(patient),
          gender: person[:gender],
          birthdate: person[:birthdate],
          birthdate_estimated: person[:birthdate_estimated]
        }
      end

      private

      def read_person_names(patient)
        LOGGER.debug("Reading eMastercard person names for patient ##{patient[:patient_id]}")
        sequel[:person_name].select(:given_name, :family_name, :middle_name)
                            .where(person_id: patient[:patient_id])
                            .to_a
      end

      def read_person_attributes(patient)
        LOGGER.debug("Reading eMastercard person attributes for patient ##{patient[:patient_id]}")
        attributes = []

        unless patient[:patient_phone]&.strip&.empty?
          attributes << {
            person_attribute_type_id: Nart::PersonAttributeTypes::PHONE_NUMBER,
            value: patient[:patient_phone]
          }
        end

        addresses = sequel[:person_address].where(person_id: patient[:patient_id])
                                           .select(:city_village)
        addresses.each do |address|
          landmark = address[:city_village]&.strip
          next if landmark.nil? || landmark.empty?

          attributes.append(
            person_attribute_type_id: Nart::PersonAttributeTypes::LANDMARK,
            value: landmark
          )
        end

        attributes
      end

      def read_person_relationships(patient)
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
