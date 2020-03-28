# frozen_string_literal: true

require_relative './constants'

require 'sequel'

module Emastercard
  module Indicators
    def self.outcome(db, patient_id)
      db[:obs].join(:encounter, encounter_id: :encounter_id)
              .where(concept_id: Emastercard::Concepts::OUTCOME,
                     patient_id: patient_id)
              .exclude(value_text: nil)
              .order(Sequel.lit('encounter_datetime DESC'))
              .limit(1)
              .select(:value_text, :encounter_datetime)
              .map(%i[value_text encounter_datetime])
              .first
    end
  end
end
