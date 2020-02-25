# frozen_string_literal: true

module Transformers
  module Encounters
    module HivStaging
      class << self
        include EmastercardDb

        def transform(patient, visit)
          observations = [
            tb_status_at_initiation(patient, visit),
            kaposis_sarcoma(patient, visit),
            pregnant_or_breastfeeding(patient, visit)
          ]

          {
            encounter_type_id: Nart::Encounters::HIV_STAGING,
            encounter_datetime: visit[:encounter_datetime],
            observations: observations.reject(&:nil?)
          }
        end

        private

        def tb_status_at_initiation(patient, visit)
          case EmastercardDb.find_observation(patient[:patient_id], Emastercard::Concepts::INITIAL_TB_STATUS)
                            &.value_text
          when /Last 2years/i
            {
              concept_id: Nart::Concepts::PTB_WITHIN_LAST_2_YEARS,
              obs_datetime: visit[:encounter_datetime],
              value_coded: Nart::Concepts::YES
            }
          when /Never > 2years/i
            {
              concept_id: Nart::Concepts::PTB_WITHIN_LAST_2_YEARS,
              obs_datetime: visit[:encounter_datetime],
              value_coded: Nart::Concepts::NO
            }
          end
        end

        def kaposis_sarcoma(patient, visit)
          case EmastercardDb.find_observation(patient[:patient_id], Emastercard::Concepts::KS)
                            &.value_text
          when /y/i
            {
              concept_id: Nart::Concepts::KAPOSIS_SARCOMA,
              obs_datetime: visit[:encounter_datetime],
              value_coded: Nart::Concepts::YES
            }
          when /n/i
            {
              concept_id: Nart::Concepts::KAPOSIS_SARCOMA,
              obs_datetime: visit[:encounter_datetime],
              value_coded: Nart::Concepts::YES
            }
          end
        end

        def pregnant_or_breastfeeding(patient, visit)
          case patient[:preg_breast_feeding]
          when /bf/i
            {
              concept_id: Nart::Concepts::BREAST_FEEDING,
              obs_datetime: visit[:encounter_datetime],
              value_coded: Nart::Concepts::YES
            }
          when /preg/i
            {
              concept_id: Nart::Concepts::PATIENT_PREGNANT,
              obs_datetime: visit[:encounter_datetime],
              value_coded: Nart::Concepts::YES
            }
          when /(n|blank)/i
            {
              concept_id: Nart::Concepts::PATIENT_PREGNANT,
              obs_datetime: visit[:encounter_datetime],
              value_coded: Nart::Concepts::NO
            }
          end
        end
      end
    end
  end
end
