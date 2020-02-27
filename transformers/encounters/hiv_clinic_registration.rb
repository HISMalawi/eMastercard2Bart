# frozen_string_literal: true

module Transformers
  module Encounters
    module HivClinicRegistration
      class << self
        include EmastercardDb

        def transform(patient, visit)
          observations = [
            ever_registered_at_art_clinic(patient, visit),
            ever_received_art(patient, visit),
            date_antiretrovirals_started(patient, visit),
            follow_up_agreement(patient, visit),
            confirmatory_hiv_test_type(patient, visit)
          ]

          {
            encounter_type_id: Nart::Encounters::HIV_CLINIC_REGISTRATION,
            encounter_datetime: visit[:encounter_datetime],
            observations: observations.reject(&:nil?)
          }
        end

        private

        def ever_registered_at_art_clinic(patient, visit)
          registration_type = EmastercardDb.find_observation_by_encounter(
            patient[:patient_id],
            Emastercard::Concepts::CLINICAL_REGISTRATION_TYPE,
            Emastercard::Encounters::ART_REGISTRATION
          )&.[](:value_text)

          return nil unless registration_type

          {
            concept_id: Nart::Concepts::EVER_REGISTERED_AT_ART_CLINIC,
            obs_datetime: visit[:encounter_datetime],
            value_coded: if ['reinitiation', 'transfer in'].include?(registration_type.downcase)
                           Nart::Concepts::YES
                         else
                           Nart::Concepts::NO
                         end
          }
        end

        def ever_received_art(patient, visit)
          ever_received_arts = EmastercardDb.find_observation(
            patient[:patient_id],
            Emastercard::Concepts::EVER_TAKEN_ARVS,
            Emastercard::Encounters::ART_STATUS_AT_INITIATION
          )&.[](:value_text)

          return nil unless ever_received_arts

          {
            concept_id: Emastercard::Concepts::EVER_TAKEN_ARVS,
            obs_datetime: visit[:encounter_datetime],
            value_coded: case ever_received_arts.upcase
                         when 'Y' then Nart::Concepts::YES
                         when 'N' then Nart::Concepts::NO
                         end
          }
        end

        def date_antiretrovirals_started(patient, visit)
          art_start_date = EmastercardDb.find_observation_by_encounter(
            patient[:patient_id],
            Emastercard::Concepts::CLINICAL_REGISTRATION_ART_START_DATE,
            Emastercard::Encounters::ART_REGISTRATION
          )&.[](:value_datetime)

          return nil unless art_start_date

          {
            concept_id: Nart::Concepts::DATE_ANTIRETROVIRALS_STARTED,
            obs_datetime: visit[:encounter_datetime],
            value_datetime: art_start_date
          }
        end

        def follow_up_agreement(patient, visit)
          return nil unless patient[:follow_up]

          {
            concept_id: Nart::Concepts::AGREES_TO_FOLLOW_UP,
            obs_datetime: visit[:encounter_datetime],
            value_coded: case patient[:follow_up].upcase
                         when 'TRUE' then  Nart::Concepts::YES
                         when 'FALSE' then Nart::Concepts::NO
                         end
          }
        end

        def confirmatory_hiv_test_type(patient, visit)
          case EmastercardDb.find_observation(patient[:patient_id],
                                              Emastercard::Concepts::CONFIRMATORY_HIV_TEST, 
                                              Emastercard::Encounters::ART_CONFIRMATORY_TEST)
                            &.[](:value_text)
          when /PCR/i
            {
              concept_id: Nart::Concepts::CONFIRMATORY_HIV_TEST_TYPE,
              obs_datetime: visit[:encounter_datetime],
              value_coded: Nart::Concepts::DNA_PCR
            }
          when /Rapid/i
            {
              concept_id: Nart::Concepts::CONFIRMATORY_HIV_TEST_TYPE,
              obs_datetime: visit[:encounter_datetime],
              value_coded: Nart::Concepts::HIV_RAPID_TEST
            }
          end
        end
      end
    end
  end
end
