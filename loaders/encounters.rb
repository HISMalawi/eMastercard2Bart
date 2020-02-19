# frozen_string_literal: true

# Constructs an encounter -> observations and orders tree from an
# eMastercard patient and database.

require 'json'
require_relative '../emastercard_db_utils'
require_relative 'encounters/registration'
require_relative 'encounters/hiv_clinic_registration'
require_relative 'encounters/hiv_staging'
require_relative 'encounters/hiv_reception'
require_relative 'encounters/art_adherence'
require_relative 'encounters/vitals'
require_relative 'encounters/hiv_clinic_consultation'
require_relative 'encounters/treatment'
require_relative 'encounters/dispensing'
require_relative 'encounters/appointment'

module Loaders
  module Encounters
    class << self
      include EmastercardDbUtils

      def load(patient, visits = nil, initial_visit = true)
        visits ||= find_patient_visits(patient[:patient_id]).to_a
        return [] if visits.empty?

        visit = visits.first
        encounters = []

        if initial_visit
          encounters << Encounters::Registration.load(patient, visit)
          encounters << Encounters::HivClinicRegistration.load(patient, visit)
          encounters << Encounters::HivStaging.load(patient, visit)
        else
          # These never happen on an initial visit
          encounters << Encounters::ArtAdherence.load(patient, visit)
        end

        # Append encounters that occur on every visit
        encounters << Encounters::HivReception.load(patient, visit)
        encounters << Encounters::Vitals.load(patient, visit)
        encounters << Encounters::HivClinicConsultation.load(patient, visit)
        # encounters << hiv_clinic_consultation_clinician(patient, visit_date)
        encounters << Encounters::Treatment.load(patient, visit)
        encounters << Encounters::Dispensing.load(patient, visit)
        encounters << Encounters::Appointment.load(patient, visit)

        encounters + load(patient, visits[1..visits.size], false)
      end

      def find_patient_visits(patient_id)
        sequel[:visit_outcome_event].where(event_type: 'Clinical Visit', person_id: patient_id)
                                    .order(:encounter_datetime)
      end
    end
  end
end
