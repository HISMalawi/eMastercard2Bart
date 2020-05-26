# frozen_string_literal: true

module Transformers
  module Encounters
    module Vitals
      class << self
        def transform(patient, visit, person)
          vitals = vitals(patient, visit, person)

          {
            encounter_type_id: Nart::Encounters::VITALS,
            encounter_datetime: retro_date(visit[:encounter_datetime]),
            observations: vitals.reject(&:nil?)
          }
        end

        def vitals(patient, visit, person)
          vitals = []

          weight = weight(patient, visit[:encounter_datetime])
          if weight
            vitals << weight
          else
            patient[:errors] << "Missing weight on visit #{visit[:encounter_datetime]}"
          end

          if person[:birthdate] && person_age(person[:birthdate]) > 18
            height = height(patient, visit[:encounter_datetime])
            if height
              vitals << height
            else
              patient[:errors] << "Missing height on visit #{visit[:encounter_datetime]}"
            end
          end

          vitals
        end

        def height(patient, date)
          height = EmastercardDb.from_table[:obs]
                                .join(:encounter, encounter_id: :encounter_id) 
                                .where(concept_id: [Emastercard::Concepts::HEIGHT1, Emastercard::Concepts::HEIGHT2],
                                       Sequel[:encounter][:encounter_datetime] => date,
                                       person_id: patient[:patient_id])
                                .exclude(value_numeric: nil)
                                .first
                                &.[](:value_numeric)

          return nil unless height

          {
            concept_id: Nart::Concepts::HEIGHT,
            obs_datetime: retro_date(date),
            value_numeric: height
          }
        end

        def weight(patient, date)
          weight = EmastercardDb.from_table[:obs]
                                .join(:encounter, encounter_id: :encounter_id)
                                .where(concept_id: [Emastercard::Concepts::WEIGHT1, Emastercard::Concepts::WEIGHT2],
                                       Sequel[:encounter][:encounter_datetime] => date,
                                       person_id: patient[:patient_id])
                                .exclude(value_numeric: nil)
                                .first
                                &.[](:value_numeric)

          return nil unless weight

          {
            concept_id: Nart::Concepts::WEIGHT,
            obs_datetime: retro_date(date),
            value_numeric: weight
          }
        end

        def person_age(birthdate)
          (Date.today - birthdate.to_date).to_i
        end
      end
    end
  end
end
