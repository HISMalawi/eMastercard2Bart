# frozen_string_literal: true

module Transformers
  module Encounters
    module Appointment
      class << self
        def transform(patient, visit)
          observations = [appointment_date(patient, visit)]

          {
            encounter_type_id: Nart::Encounters::APPOINTMENT,
            encounter_datetime: retro_date(visit[:encounter_datetime]),
            observations: observations.reject(&:nil?)
          }
        end

        def appointment_date(patient, visit)
          observation = EmastercardDb.find_observation_by_date(
            patient[:patient_id],
            Emastercard::Concepts::NEXT_APPOINTMENT_DATE,
            visit[:encounter_datetime]
          )

          unless observation
            patient[:errors] << "Missing appointment date on visit ##{visit[:encounter_datetime]}"
            return nil
          end

          {
            concept_id: Nart::Concepts::NEXT_APPOINTMENT_DATE,
            obs_datetime: retro_date(visit[:encounter_datetime]),
            value_datetime: observation[:value_datetime]
          }
        end
      end
    end
  end
end
