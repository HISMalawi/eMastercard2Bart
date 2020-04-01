# frozen_string_literal: true

require_relative 'nart/constants'
require_relative 'nart/indicators'

module Nart
  def self.find_patient_id(db, arv_number)
    db[:patient_identifier]
      .where(identifier_type: Nart::PatientIdentifierTypes::ARV_NUMBER,
             identifier: /^.*-#{arv_number}$/,
             voided: false)
      .first
      &.[](:patient_id)
  end

  def self.read_indicator(db, indicator, patient_id, date)
    Nart::Indicators.send(indicator, db, patient_id, date)
  end
end
