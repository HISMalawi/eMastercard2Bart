# frozen_string_literal: true
require 'byebug'
require 'json'

require_relative 'emastercard_constants'
require_relative 'emastercard_db_utils'
require_relative 'emastercard_reader'
require_relative 'logging'
require_relative 'nart_constants'
require_relative 'nart_db_utils'

require_relative 'transformers/patient'

EmastercardReader.read_patients.each do |patient|
  print(JSON.dump(Transformers::Patient.transform(patient)))
end
