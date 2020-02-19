# frozen_string_literal: true

module Loaders
  module Encounters
    module Vitals
      class << self
        def load(_patient, visit)
          observations = [{
            concept_id: Nart::Concepts::WEIGHT,
            obs_datetime: visit[:encounter_datetime],
            value_numeric: visit[:weight]
          }]

          if visit[:height] # This is collected on initial visit only for adults
            observations << {
              concept_id: Nart::Concepts::HEIGHT,
              obs_datetime: visit[:encounter_datetime],
              value_numeric: visit[:height]
            }
          end

          {
            encounter_type: Nart::Encounters::VITALS,
            encounter_datetime: visit[:encounter_datetime],
            observations: observations
          }
        end
      end
    end
  end
end
