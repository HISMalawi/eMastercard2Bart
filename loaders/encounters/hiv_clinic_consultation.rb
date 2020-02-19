# frozen_string_literal: true

module Loaders
  module Encounters
    module HivClinicConsultation
      class << self
        def load(patient, visit); end

        def hiv_clinic_consultation(patient, visit)
          {
            encounter_type: 'HIV Clinic Consultation',
            encounter_datetime: visit[:encounter_datetime],
            observations: []
          }
        end

        def hiv_clinic_consultation_clinician(patient, visit_date)
        end
      end
    end
  end
end
