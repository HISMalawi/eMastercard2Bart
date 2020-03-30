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

        def collect_initial_visit_vitals(patient, visit)
          vitals = []

          height = find_initial_patient_height(patient, visit[:encounter_datetime])
          if height
            vitals << height
          else
            patient[:errors] << "Missing height on initial visit #{visit[:encounter_datetime]}"
          end

          weight = find_initial_patient_weight(patient, visit[:encounter_datetime])
          if weight
            vitals << weight
          else
            patient[:errors] << "Missing weight on initial visit #{visit[:encounter_datetime]}"
          end

          vitals
        end

        def collect_regular_visit_vitals(patient, visit, person)
          vitals = []

          weight = find_patient_weight(patient, visit[:encounter_datetime])
          if weight
            vitals << weight
          else
            patient[:errors] << "Missing weight on visit #{visit[:encounter_datetime]}"
          end

          if person[:birthdate] && person_age(person[:birthdate]) > 18
            height = find_patient_height(patient, visit[:encounter_datetime])
            if height
              vitals << height
            else
              patient[:errors] << "Missing height on visit #{visit[:encounter_datetime]}"
            end
          end

          vitals
        end

        def find_patient_height(patient, date)
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
            obs_datetime: date,
            value_numeric: height
          }
        end

        def find_initial_patient_height(patient, date)
          height = EmastercardDb.from_table[:obs]
                                .join(:encounter, encounter_id: :encounter_id) 
                                .where(concept_id: [Emastercard::Concepts::HEIGHT1, Emastercard::Concepts::HEIGHT2],
                                       person_id: patient[:patient_id],
                                       Sequel[:encounter][:encounter_type] => Emastercard::Encounters::ART_STATUS_AT_INITIATION)
                                .exclude(value_numeric: nil)
                                .first
                                &.[](:value_numeric)

          return nil unless height

          {
            concept_id: Nart::Concepts::HEIGHT,
            obs_datetime: date,
            value_numeric: height
          }
        end

        def find_patient_weight(patient, date)
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
            obs_datetime: date,
            value_numeric: weight
          }
        end

        def find_initial_patient_weight(patient, date)
          weight = EmastercardDb.from_table[:obs]
                                .join(:encounter, encounter_id: :encounter_id)
                                .where(concept_id: [Emastercard::Concepts::WEIGHT1, Emastercard::Concepts::WEIGHT2],
                                       Sequel[:encounter][:encounter_type] => Emastercard::Encounters::ART_STATUS_AT_INITIATION,
                                       person_id: patient[:patient_id])
                                .exclude(value_numeric: nil)
                                .first
                                &.[](:value_numeric)

          return nil unless weight

          {
            concept_id: Nart::Concepts::WEIGHT,
            obs_datetime: date,
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
