# frozen_string_literal.rb

module Transformers
  module Encounters
    module Registration
      def self.transform(patient, visit)
        registration_date = clinical_registration_date(patient, visit)

        {
          encounter_type_id: Nart::Encounters::REGISTRATION,
          encounter_datetime: retro_date(registration_date),
          observations: [
            {
              concept_id: Nart::Concepts::TYPE_OF_PATIENT,
              obs_datetime: retro_date(registration_date),
              value_coded: Nart::Concepts::NEW_PATIENT
            }
          ]
        }
      end

      def self.clinical_registration_date(patient, visit)
        registration_date = EmastercardDb.find_observation_by_encounter(
          patient[:patient_id],
          Emastercard::Concepts::CLINICAL_REGISTRATION_DATE,
          Emastercard::Encounters::ART_REGISTRATION
        )&.[](:value_datetime)

        return registration_date if registration_date

        return visit[:encounter_datetime] if visit

        first_encounter_datetime = EmastercardDb.from_table[:encounter]
                                                .where(patient_id: patient[:patient_id])
                                                .order(:encounter_datetime)
                                                .first
                                                &.[](:encounter_datetime)

        return first_encounter_datetime if first_encounter_datetime

        EmastercardDb.from_table[:patient]
                     .where(patient_id: patient[:patient_id])
                     .first
                     .[](:date_created)
      end
    end
  end
end
