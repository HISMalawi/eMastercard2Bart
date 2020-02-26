# frozen_string_literal: true

require_relative 'person'

module Loaders
  module Patient
    def self.load(patient)
      LOGGER.debug("Saving patient: #{JSON.dump(patient)}")
      person_id = Person.load(patient[:person])
      patient_id = load_patient(person_id)
      load_patient_identifiers(patient_id, patient[:identifiers])
      load_encounters(patient_id, patient[:encounters])
      load_programs(patient_id, patient[:programs])
      patient_id
    end

    def self.load_patient(person_id)
      LOGGER.debug("Saving patient ##{person_id}")
      NartDb.into_table[:patient]
            .insert(patient_id: person_id,
                    creator: EMR_USER_ID,
                    date_created: DateTime.now)
    end

    def self.load_patient_identifiers(patient_id, identifiers)
      LOGGER.debug("Saving patient ##{patient_id} identifiers")
      identifiers.each do |identifier|
        NartDb.into_table[:patient_identifier]
              .insert(patient_id: patient_id,
                      creator: EMR_USER_ID,
                      date_created: DateTime.now,
                      location_id: EMR_USER_ID,
                      uuid: SecureRandom.uuid,
                      **identifier)
      end
    end

    def self.load_encounters(patient_id, encounters)
      LOGGER.debug("Saving patient ##{patient_id} encounters")
      encounters.each do |encounter|
        unless encounter[:observations]&.size&.positive? || encounter[:orders]&.size&.positive?
          LOGGER.warn("Skipping empty encounter: #{encounter}")
          next
        end

        LOGGER.debug("Saving patient ##{patient_id} encounter: #{encounter[:encounter_datetime]} - #{encounter[:encounter_type_id]}")
        encounter_id = NartDb.into_table[:encounter]
                             .insert(encounter_type: encounter[:encounter_type_id],
                                     patient_id: patient_id,
                                     program_id: Nart::Programs::HIV_PROGRAM,
                                     encounter_datetime: encounter[:encounter_datetime],
                                     date_created: DateTime.now,
                                     creator: EMR_USER_ID,
                                     provider_id: EMR_USER_ID,
                                     location_id: EMR_LOCATION_ID,
                                     uuid: SecureRandom.uuid)

        load_observations(patient_id, encounter_id, encounter[:observations])
        load_orders(patient_id, encounter_id, encounter[:orders])
      end
    end

    def self.load_observations(patient_id, encounter_id, observations)
      LOGGER.debug("Saving observations for encounter ##{encounter_id}")
      observations&.each do |observation|
        LOGGER.debug("Saving encounter ##{encounter_id} observation: #{observation[:obs_datetime]} - #{observation[:concept_id]}")
        observation = observation.dup
        children = observation.delete(:children)

        observation_id = NartDb.into_table[:obs]
                               .insert(uuid: SecureRandom.uuid,
                                       creator: EMR_USER_ID,
                                       date_created: DateTime.now,
                                       location_id: EMR_LOCATION_ID,
                                       encounter_id: encounter_id,
                                       person_id: patient_id,
                                       comments: 'Migrated from eMastercard',
                                       **observation)

        next unless children

        LOGGER.debug("Saving observation ##{observation} children")
        load_observations(patient_id,
                          encounter_id,
                          children.map { |child| { obs_group_id: observation_id, **child } })
      end
    end

    def self.load_orders(patient_id, encounter_id, orders)
      LOGGER.debug("Saving orders for encounter ##{encounter_id}")
      orders&.each do |order|
        order = order.dup
        drug_order = order.delete(:drug_order)
        observation = order.delete(:observation)

        order_id = NartDb.into_table[:orders]
                         .insert(uuid: SecureRandom.uuid,
                                 patient_id: patient_id,
                                 orderer: EMR_USER_ID,
                                 creator: EMR_USER_ID,
                                 date_created: DateTime.now,
                                 encounter_id: encounter_id,
                                 **order)

        load_drug_order(order_id, drug_order) if drug_order
        load_observations(patient_id, encounter_id, [{ order_id: order_id, **observation }]) if observation
      end
    end

    def self.load_drug_order(order_id, drug_order)
      LOGGER.debug("Saving drug order for order ##{order_id}")
      NartDb.into_table[:drug_order]
            .insert(order_id: order_id, **drug_order)
    end

    def self.load_programs(patient_id, programs)
      LOGGER.debug("Saving patient ##{patient_id} programs")
      programs.each do |program|
        program = program.dup
        states = program.delete(:states)

        patient_program_id = NartDb.into_table[:patient_program]
                                   .insert(patient_id: patient_id,
                                           uuid: SecureRandom.uuid,
                                           date_created: DateTime.now,
                                           creator: EMR_USER_ID,
                                           **program)
        load_patient_states(patient_program_id, states)
      end
    end

    def self.load_patient_states(patient_program_id, states)
      LOGGER.debug("Saving patient_program ##{patient_program_id} states")
      states.each do |state|
        NartDb.into_table[:patient_state]
              .insert(patient_program_id: patient_program_id,
                      uuid: SecureRandom.uuid,
                      creator: EMR_USER_ID,
                      date_created: DateTime.now,
                      **state)
      end
    end
  end
end
