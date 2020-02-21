# frozen_string_literal: true

module Transformers
  module Encounters
    module Appointment
      class << self
        include EmastercardDbUtils

        def transform(patient, visit)
          observations = [appointment_date(patient, visit)]

          {
            encounter_type: Nart::Encounters::APPOINTMENT,
            encounter_datetime: visit[:encounter_datetime],
            observations: observations.select
          }
        end

        def appointment_date(patient, visit)
          find_observation_by_date(patient[:patient_id],
                                   Emastercard::Concepts::NEXT_APPOINTMENT_DATE,
                                   visit[:encounter_datetime])
            &.[](:value_datetime)
        end
      end
    end
  end
end
