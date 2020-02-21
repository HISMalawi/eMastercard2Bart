# frozen_string_literal: true

module Loaders
  module Encounters
    module HivReception
      class << self
        def load(_patient, visit)
          {
            encounter_type_id: Nart::Encounters::HIV_RECEPTION,
            encounter_datetime: visit[:encounter_datetime],
            observations: [
              {
                concept_id: Nart::Concepts::PATIENT_PRESENT,
                obs_datetime: visit[:encounter_datetime],
                value_coded: visit[:arvs_given_to] != 'G' ? Nart::Concepts::YES : Nart::Concepts::NO
              },
              {
                concept_id: Nart::Concepts::GUARDIAN_PRESENT,
                obs_datetime: visit[:encounter_datetime],
                value_coded: visit[:arvs_given_to] == 'G' ? Nart::Concepts::YES : Nart::Concepts::NO
              }
            ]
          }
        end
      end
    end
  end
end
