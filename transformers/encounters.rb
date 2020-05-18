# frozen_string_literal: true

# Constructs an encounter -> observations and orders tree from an
# eMastercard patient and database.

require_relative 'encounters/registration'
require_relative 'encounters/hiv_clinic_registration'
require_relative 'encounters/hiv_staging'
require_relative 'encounters/hiv_reception'
require_relative 'encounters/art_adherence'
require_relative 'encounters/initial_vitals'
require_relative 'encounters/vitals'
require_relative 'encounters/hiv_clinic_consultation'
require_relative 'encounters/treatment'
require_relative 'encounters/dispensing'
require_relative 'encounters/appointment'

module Transformers
  module Encounters
    def self.transform(patient, visits, previous_visit = nil, person)
      is_initial_visit = -> { previous_visit.nil? }

      # if no visits and no previous visit then patient has no
      # visits but we still need to try to pull out staging info
      # and initial vitals (ie from transfer-in).
      return [] if visits.empty? && previous_visit

      visit = visits.first
      encounters = []

      if is_initial_visit.call
        registration = Encounters::Registration.transform(patient, visit)
        clinic_registration = Encounters::HivClinicRegistration.transform(patient, registration)

        encounters << registration << clinic_registration
        encounters << Encounters::HivStaging.transform(patient, registration)
        encounters << Encounters::InitialVitals.transform(patient, clinic_registration)

        encounters << Encounters::Treatment.transform(patient) unless visit
      else
        # These never happen on an initial visit
        encounters << Encounters::ArtAdherence.transform(patient, visit, previous_visit)
      end

      return encounters unless visit

      # Append encounters that occur on every visit
      encounters << Encounters::HivReception.transform(patient, visit)
      encounters << Encounters::Vitals.transform(patient, visit, person)
      encounters << Encounters::HivClinicConsultation.transform(patient, visit)
      # encounters << hiv_clinic_consultation_clinician(patient, visit_date)
      encounters << Encounters::Treatment.transform(patient, visit)

      encounters << Encounters::Dispensing.transform(patient, visit, encounters.last)
      encounters << Encounters::Appointment.transform(patient, visit)

      encounters + transform(patient, visits[1..visits.size], visit, person)
    end
  end
end
