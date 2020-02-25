# frozen_string_literal: true

require_relative 'person'

module Loaders
  module Patient
    def self.load(patient)
      person_id = Person.load(patient[:person])
      byebug
    end
  end
end
