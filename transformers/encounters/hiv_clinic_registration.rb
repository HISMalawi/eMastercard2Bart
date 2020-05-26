# frozen_string_literal: true

module Transformers
  module Encounters
    module HivClinicRegistration
      class << self
        include EmastercardDb

        DAYS_IN_YEARS = 365
        DAYS_IN_MONTH = 30

        def transform(patient, registration_encounter)
          observations = [
            ever_registered_at_art_clinic(patient, registration_encounter),
            ever_received_art(patient, registration_encounter),
            date_antiretrovirals_started(patient, registration_encounter),
            follow_up_agreement(patient, registration_encounter),
            confirmatory_hiv_test_type(patient, registration_encounter)
          ]

          {
            encounter_type_id: Nart::Encounters::HIV_CLINIC_REGISTRATION,
            encounter_datetime: retro_date(registration_encounter[:encounter_datetime]),
            observations: observations.reject(&:nil?)
          }
        end

        private

        def ever_registered_at_art_clinic(patient, registration_encounter)
          registration_type = EmastercardDb.find_observation_by_encounter(
            patient[:patient_id],
            Emastercard::Concepts::CLINICAL_REGISTRATION_TYPE,
            Emastercard::Encounters::ART_REGISTRATION
          )&.[](:value_text)

          unless registration_type
            patient[:errors] << "Missing clinical_registration_type on #{registration_encounter[:encounter_datetime]}"
            return nil
          end

          {
            concept_id: Nart::Concepts::EVER_REGISTERED_AT_ART_CLINIC,
            obs_datetime: retro_date(registration_encounter[:encounter_datetime]),
            value_coded: if ['reinitiation', 'transfer in'].include?(registration_type.downcase)
                           Nart::Concepts::YES
                         else
                           Nart::Concepts::NO
                         end
          }
        end

        def ever_received_art(patient, registration_encounter)
          ever_received_arts = EmastercardDb.find_observation(
            patient[:patient_id],
            Emastercard::Concepts::EVER_TAKEN_ARVS,
            Emastercard::Encounters::ART_STATUS_AT_INITIATION
          )&.[](:value_text)

          unless ever_received_arts
            patient[:errors] << "Missing ever_received_art on #{registration_encounter[:encounter_datetime]}"
            return nil
          end

          {
            concept_id: Emastercard::Concepts::EVER_TAKEN_ARVS,
            obs_datetime: retro_date(registration_encounter[:encounter_datetime]),
            value_coded: case ever_received_arts.upcase
                         when 'Y' then Nart::Concepts::YES
                         when 'N' then Nart::Concepts::NO
                         end
          }
        end

        def date_antiretrovirals_started(patient, registration_encounter)
          # NART's ART start date is either the actual date on which a patient
          # started ART on an estimate of when a patient started ART. In
          # eMastercard on the other hand if an actual date is not available an
          # estimated age is stored. Finding an ART start date for NART
          # thus must start with checking the actual date then fall back to
          # the estimated age if that fails.
          art_start_date = EmastercardDb.find_observation_by_encounter(
            patient[:patient_id],
            Emastercard::Concepts::CLINICAL_REGISTRATION_ART_START_DATE,
            Emastercard::Encounters::ART_REGISTRATION
          )

          if art_start_date && art_start_date[:value_datetime]
            return {
              concept_id: Nart::Concepts::DATE_ANTIRETROVIRALS_STARTED,
              obs_datetime: retro_date(registration_encounter[:encounter_datetime]),
              value_datetime: art_start_date[:value_datetime]
            }
          elsif patient[:birthdate].nil?
            patient[:errors] << "Can't estimate art_start_date due to missing birthdate on #{registration_encounter[:encounter_datetime]}"
            return nil
          end

          # Estimate ART start date from initiation age.
          age_at_initiation = EmastercardDb.find_observation_by_encounter(
            patient[:patient_id],
            Emastercard::Concepts::CLINICAL_REGISTRATION_ART_INITIATION_AGE,
            Emastercard::Encounters::ART_REGISTRATION
          )

          unless age_at_initiation && age_at_initiation[:value_numeric]
            patient[:errors] << "Missing art_start_date and initiation_age on #{registration_encounter[:encounter_datetime]}"
            return nil
          end

          # Convert the age from months or years to days
          age_type = EmastercardDb.find_observation_by_encounter(
            patient[:patient_id],
            Emastercard::Concepts::CLINICAL_REGISTRATION_ART_INITIATION_AGE_TYPE,
            Emastercard::Encounters::ART_REGISTRATION
          )

          unless age_type && age_type[:value_text]
            patient[:errors] << "Missing initiation_age_type on #{registration_encounter[:encounter_datetime]}"
            return nil
          end

          age_in_days = case age_type[:value_text].downcase
                        when 'years' then age_at_initiation[:value_numeric] * DAYS_IN_YEARS
                        when 'months' then age_at_initiation[:value_numeric] * (DAYS_IN_YEARS.to_f / DAYS_IN_MONTH)
                        end

          unless age_in_days
            patient[:errors] << "Invalid initiation_age_type '#{age_type[:value_text]}' on #{registration_encounter[:encounter_datetime]}"
            return nil
          end

          # Marching on to Valhalla
          {
            concept_id: Nart::Concepts::DATE_ANTIRETROVIRALS_STARTED,
            obs_datetime: retro_date(registration_encounter[:encounter_datetime]),
            value_datetime: patient[:birthdate].to_date + age_in_days,
            comments: 'Estimated from eMastercard Clinical Registration ART Initiation Age'
          }
        end

        def follow_up_agreement(patient, registration_encounter)
          unless patient[:follow_up]
            patient[:errors] << "Missing follow_up_agreement on #{registration_encounter[:encounter_datetime]}"
            return nil
          end

          {
            concept_id: Nart::Concepts::AGREES_TO_FOLLOW_UP,
            obs_datetime: registration_encounter[:encounter_datetime],
            value_coded: case patient[:follow_up].upcase
                         when 'TRUE' then  Nart::Concepts::YES
                         when 'FALSE' then Nart::Concepts::NO
                         end
          }
        end

        def confirmatory_hiv_test_type(patient, registration_encounter)
          case EmastercardDb.find_observation(patient[:patient_id],
                                              Emastercard::Concepts::CONFIRMATORY_HIV_TEST, 
                                              Emastercard::Encounters::ART_CONFIRMATORY_TEST)
                            &.[](:value_text)
          when /PCR/i
            {
              concept_id: Nart::Concepts::CONFIRMATORY_HIV_TEST_TYPE,
              obs_datetime: retro_date(registration_encounter[:encounter_datetime]),
              value_coded: Nart::Concepts::DNA_PCR
            }
          when /Rapid/i
            {
              concept_id: Nart::Concepts::CONFIRMATORY_HIV_TEST_TYPE,
              obs_datetime: retro_date(registration_encounter[:encounter_datetime]),
              value_coded: Nart::Concepts::HIV_RAPID_TEST
            }
          else
            patient[:errors] << "Missing confirmatory_hiv_test_type on #{registration_encounter[:encounter_datetime]}"
            nil
          end
        end

        def has_transfer_letter(_patient, registration_encounter)
          {
            concept_id: Nart::Concepts::HAS_TRANSFER_LETTER,
            obs_datetime: retro_date(registration_encounter[:encounter_datetime]),
            value_coded: Nart::Concepts::UNKNOWN
          }
        end
      end
    end
  end
end
