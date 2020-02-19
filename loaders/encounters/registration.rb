# frozen_string_literal.rb

module Loaders
  module Encounters
    module Registration
      class << self
        include EmastercardDbUtils

        def load(_patient, visit)
          {
            encounter_type_id: Nart::Encounters::REGISTRATION,
            encounter_datetime: visit[:encounter_datetime],
            observations: [
              {
                concept_id: Nart::Concepts::TYPE_OF_PATIENT,
                obs_datetime: visit[:encounter_datetime],
                value_coded: Nart::Concepts::NEW_PATIENT
              }
            ]
          }
        end
      end
    end
  end
end
