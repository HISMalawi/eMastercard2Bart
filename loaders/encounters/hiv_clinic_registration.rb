# frozen_string_literal: true

module Loaders
  module Encounters
    module HivClinicRegistration
      class << self
        include EmastercardDbUtils

        def load(patient, visit)
          {
            encounter_type_id: Nart::Encounters::HIV_CLINIC_REGISTRATION,
            encounter_datetime: visit[:encounter_datetime],
            observations: [
              ever_registered_at_art_clinic(patient, visit),
              # ever_received_art(patient, visit),
              date_antiretrovirals_started(patient, visit),
              follow_up_agreement(patient, visit)
            ]
          }
        end

        private

        def ever_registered_at_art_clinic(patient, visit)
          registration_type = find_observation_by_encounter(patient[:patient_id],
                                                            Emastercard::Concepts::CLINICAL_REGISTRATION_TYPE,
                                                            Emastercard::Encounters::ART_REGISTRATION)

          if ['reinitiation', 'transfer in'].include?(registration_type&.value_text&.downcase)
            {
              concept_id: Nart::Concepts::EVER_REGISTERED_AT_ART_CLINIC,
              obs_datetime: visit[:encounter_datetime],
              value_coded: Nart::Concepts::YES
            }
          else
            {
              concept_id: Nart::Concepts::EVER_REGISTERED_AT_ART_CLINIC,
              obs_datetime: visit[:encounter_datetime],
              value_coded: Nart::Concepts::NO
            }
          end
        end

        def ever_received_art(_patient, visit)
          ever_received_arts = find_observation(patient[:patient_id],
                                                EMastercardConcepts::EVER_TAKEN_ARVS)[:value_text]

          {
            concept_id: EMastercardConcepts::EVER_TAKEN_ARVS,
            obs_datetime: visit[:encounter_datetime],
            value_coded: ever_received_arts&.upcase == 'Y' ? Nart::Concepts::YES : Nart::Concepts::NO,
            value_text: ever_received_arts.nil? ? 'Estimated - eMastercard had no data for this' : nil
          }
        end

        def date_antiretrovirals_started(patient, visit)
          art_start_date = find_observation_by_encounter(patient[:patient_id],
                                                         Emastercard::Concepts::CLINICAL_REGISTRATION_ART_START_DATE,
                                                         Emastercard::Encounters::ART_REGISTRATION)

          return nil unless art_start_date&.value_datetime

          {
            concept_id: Nart::Concepts::DATE_ANTIRETROVIRALS_STARTED,
            obs_datetime: visit[:encounter_datetime],
            value_datetime: art_start_date.value_datetime
          }
        end

        def follow_up_agreement(patient, visit)
          {
            concept_id: Nart::Concepts::AGREES_TO_FOLLOW_UP,
            obs_datetime: visit[:encounter_datetime],
            value_coded: patient[:follow_up] ? Nart::Concepts::NO : Nart::Concepts::YES
          }
        end
      end
    end
  end
end
