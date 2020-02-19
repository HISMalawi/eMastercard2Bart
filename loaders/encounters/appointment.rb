# frozen_string_literal: true

module Loaders
  module Encounters
    module Appointment
      class << self
        include EmastercardDbUtils

        def load(patient, visit)
          appointment_date = find_observation_by_date(patient[:patient_id],
                                                      Emastercard::Concepts::NEXT_APPOINTMENT_DATE,
                                                      visit[:encounter_datetime])
          return [] unless appointment_date&.[](:value_datetime)

          {
            encounter_type: Nart::Encounters::APPOINTMENT,
            observations: [
              # May need to estimate drug run out date and include that too
              {
                concept_id: Nart::Concepts::NEXT_APPOINTMENT_DATE,
                obs_datetime: appointment_date[:obs_datetime],
                value_datetime: appointment_date[:value_datetime]
              }
            ]
          }
        end
      end
    end
  end
end
