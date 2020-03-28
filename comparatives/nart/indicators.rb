# frozen_string_literal: true

require_relative './constants'

require 'date'
require 'sequel'

module Nart
  module Indicators
    def self.outcome(db, patient_id, date)
      state = db[:patient_state].join(:patient_program, patient_program_id: Sequel[:patient_state][:patient_program_id])
                                .where(patient_id: patient_id)
                                .where(Sequel.lit('start_date = DATE(:date) OR (start_date <= DATE(:date) and end_date >= DATE(:date))', date: date))
                                .exclude(state: [Nart::PatientStates::PRE_ART, Nart::PatientStates::ON_TREATMENT])
                                .order(:start_date)
                                .last # Prefer newest state
                                &.[](:state)

      case state
      when Nart::PatientStates::DEFAULTED then 'DEF'
      when Nart::PatientStates::DIED then 'D'
      when Nart::PatientStates::TRANSFERRED_OUT then 'TO'
      when Nart::PatientStates::TREATMENT_STOPPED then 'STOP'
      end
    end
  end
end
