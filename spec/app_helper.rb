# frozen_string_literal: true

require 'byebug'
require 'spec_helper'
require 'sequel'

module Faker
  require_relative './emastercard_setup'

  # Returns a Sequel client bound to a test database
  def self.emastercard_database(seed_data = {})
    sequel = Sequel.sqlite
    EMastercard.create_database_schema(sequel)
    EMastercard.seed_database(sequel, seed_data)

    sequel
  end

  def self.emastercard_seed_data
    EMastercard::SEED_DATA
  end
end
