# frozen_string_literal: true

require_relative 'emastercard/indicators'

require 'sequel'

module Emastercard
  def self.read_indicator(db, indicator, patient_id)
    Emastercard::Indicators.send(indicator, db, patient_id)
  end
end
