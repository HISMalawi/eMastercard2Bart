# frozen_string_literal: true

module Transformers
  module Encounters
    module InitialVitals
      class << self
        def transform(patient, clinic_registration_encounter)
          art_start_date = find_art_start_date(clinic_registration_encounter)

          observations = [height(patient, art_start_date), weight(patient, art_start_date)]

          {
            encounter_type_id: Nart::Encounters::VITALS,
            encounter_datetime: retro_date(art_start_date),
            observations: observations.reject(&:nil?)
          }
        end

        def height(patient, date)
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
            obs_datetime: retro_date(date),
            value_numeric: height
          }
        end

        def weight(patient, date)
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
            obs_datetime: retro_date(date),
            value_numeric: weight
          }
        end

        def find_art_start_date(clinic_registration_encounter)
          clinic_registration_encounter[:observations].each do |observation|
            if observation[:concept_id] == Nart::Concepts::DATE_ANTIRETROVIRALS_STARTED
              return observation[:value_datetime]
            end
          end

          clinic_registration_encounter[:encounter_datetime]
        end
      end
    end
  end
end
