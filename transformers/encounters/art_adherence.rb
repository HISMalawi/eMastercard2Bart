# frozen_string_literal: true

module Transformers
  module Encounters
    module ArtAdherence
      class << self
        def transform(patient, current_visit, previous_visit)
          {
            encounter_type_id: Nart::Encounters::ART_ADHERENCE,
            encounter_datetime: current_visit[:encounter_datetime],
            observations: []
          }
        end

        def calculate_drug_adherence(pills_remaining)
        end
      end
    end
  end
end
