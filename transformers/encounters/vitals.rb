# frozen_string_literal: true

module Transformers
  module Encounters
    module Vitals
      class << self
        def transform(patient, visit, initial_visit, person)
          vitals = if initial_visit
                     collect_initial_visit_vitals(patient, visit)
                   else
                     collect_regular_visit_vitals(patient, visit, person)
                   end

          {
            encounter_type_id: Nart::Encounters::VITALS,
            encounter_datetime: visit[:encounter_datetime],
            observations: vitals.reject(&:nil?)
          }
        end

        VITALS_CONCEPT_MAP = {
          height: Nart::Concepts::HEIGHT,
          weight: Nart::Concepts::WEIGHT
        }.freeze

        def collect_initial_visit_vitals(patient, visit)
          VITALS_CONCEPT_MAP.each_with_object([]) do |name__concept_id, vitals|
            name, concept_id = name__concept_id
            if visit[name]
              vitals << {
                concept_id: concept_id, obs_datetime: visit[:encounter_datetime], value_numeric: visit[name]
              }
            else
              patient[:errors] << "Missing #{name} on initial visit #{visit[:encounter_datetime]}"
            end
          end
        end

        def collect_regular_visit_vitals(patient, visit, person)
          if person[:birthdate].nil? || person_age(person[:birthdate]) < 18
            return collect_initial_visit_vitals(patient, visit)
          end

          if visit[:weight]
            # For adults weight only is collected
            [
              {
                concept_id: Nart::Concepts::WEIGHT,
                obs_datetime: visit[:encounter_datetime],
                value_numeric: visit[:weight]
              }
            ]
          else
            patient[:errors] << "Missing weight on visit #{visit[:encounter_datetime]}"
            []
          end
        end

        def person_age(birthdate)
          (Date.today - birthdate.to_date).to_i
        end
      end
    end
  end
end
