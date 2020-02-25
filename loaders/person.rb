# frozen_string_literal: true

module Loaders
  module Person
    def self.load(person)
      LOGGER.debug("Saving person: #{person}")
      person_id = load_person(gender: person[:gender],
                              birthdate: person[:birthdate],
                              birthdate_estimated: person[:birthdate_estimated])
      load_person_names(person_id, person[:names])
      load_person_attributes(person_id, person[:attributes])
      load_person_relationships(person_id, person[:relationships])

      person_id
    end

    # Loads the person root entity (ie: into person table)
    def self.load_person(gender:, birthdate:, birthdate_estimated:)
      NartDb.into_table[:person]
            .insert(gender: gender,
                    birthdate: birthdate,
                    birthdate_estimated: birthdate_estimated,
                    creator: 1,
                    date_created: DateTime.now,
                    uuid: SecureRandom.uuid)
    end

    def self.load_person_names(person_id, names)
      LOGGER.debug("Saving person ##{person_id} names")
      names.map do |name|
        NartDb.into_table[:person_name]
              .insert(person_id: person_id,
                      creator: 1,
                      date_created: DateTime.now,
                      uuid: SecureRandom.uuid,
                      **name)
      end
    end

    def self.load_person_attributes(person_id, attributes)
      LOGGER.debug("Saving person ##{person_id} attributes")
      attributes.map do |attribute|
        if attribute[:value].nil?
          LOGGER.warn("Null valued attribute for person ##{person_id}: #{attribute}")
          next
        end

        NartDb.into_table[:person_attribute]
              .insert(person_id: person_id,
                      creator: 1,
                      date_created: DateTime.now,
                      uuid: SecureRandom.uuid,
                      **attribute)
      end
    end

    def self.load_person_relationships(person_id, relationships)
      LOGGER.debug("Saving person ##{person_id} relationships")
      relationships.each do |relationship|
        other_person = relationship[:person_b]

        other_person_id = load_person(gender: nil, birthdate: nil, birthdate_estimated: false)
        load_person_names(other_person_id, other_person[:names])
        load_person_attributes(other_person_id, other_person[:attributes])
        NartDb.into_table[:relationship]
              .insert(person_a: person_id,
                      person_b: other_person_id,
                      relationship: relationship[:relationship_type_id],
                      creator: 1,
                      date_created: DateTime.now,
                      uuid: SecureRandom.uuid)
      end
    end
  end
end
