# frozen_string_literal: true

module Transformers
  module Encounters
    module Appointment
      class << self
        def transform(patient, visit)
          observations = [appointment_date(patient, visit)]

          {
            encounter_type_id: Nart::Encounters::APPOINTMENT,
            encounter_datetime: visit[:encounter_datetime],
            observations: observations.reject(&:nil?)
          }
        end

        def appointment_date(patient, visit)
          observation = EmastercardDb.find_observation_by_date(
            patient[:patient_id],
            Emastercard::Concepts::NEXT_APPOINTMENT_DATE,
            visit[:encounter_datetime]
          )

          return nil unless observation

          {
            concept_id: Nart::Concepts::NEXT_APPOINTMENT_DATE,
            obs_datetime: visit[:encounter_datetime],
            value_datetime: observation[:value_datetime],
          }
        end
      end
    end
  end
end
