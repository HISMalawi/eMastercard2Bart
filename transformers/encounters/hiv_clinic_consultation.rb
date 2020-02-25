# frozen_string_literal: true

module Transformers
  module Encounters
    module HivClinicConsultation
      class << self
        def transform(patient, visit)
          observations = [side_effects(patient, visit), on_tb_treatment(patient, visit)]

          {
            encounter_type_id: Nart::Encounters::HIV_CLINIC_CONSULTATION,
            encounter_datetime: visit[:encounter_datetime],
            observations: observations.reject(&:nil?)
          }
        end

        def side_effects(_patient, visit)
          return nil unless visit[:'side effects']

          {
            concept_id: Nart::Concepts::ART_SIDE_EFFECTS,
            obs_datetime: visit[:encounter_datetime],
            value_coded: Nart::Concepts::UNKNOWN,
            children: [
              {
                concept_id: Nart::Concepts::UNKNOWN,
                obs_datetime: visit[:encounter_datetime],
                value_coded: case visit[:'side effects'].upcase
                             when 'Y' then Nart::Concepts::YES
                             when 'N' then Nart::Concepts::NO
                             end,
                comments: 'Migrated from eMastercard 1.0'
              }
            ]
          }
        end

        def on_tb_treatment(_patient, visit)
          return nil unless visit[:tb_tatus] # tb_tatus [sic] - that's how it's named in eMastercard]

          {
            concept_id: Nart::Concepts::TB_STATUS,
            obs_datetime: visit[:encounter_datetime],
            value_coded: case visit[:tb_tatus]
                         when 'Rx' then Nart::Concepts::ON_TB_TREATMENT
                         when 'Y' then Nart::Concepts::TB_SUSPECTED
                         when 'N' then Nart::Concepts::TB_NOT_SUSPECTED
                         when 'C' then Nart::Concepts::TB_CONFIRMED_BUT_NOT_ON_TREATMENT
                         end
          }
        end
      end
    end
  end
end
