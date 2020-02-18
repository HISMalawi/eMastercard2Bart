# frozen_string_literal: true
require 'json'

require_relative 'emastercard_constants'
require_relative 'emastercard_db_utils'
require_relative 'nart_constants'
require_relative 'loaders/patients'

Loaders::Patients.load.each do |patient|
  print JSON.dump(patient)
end
