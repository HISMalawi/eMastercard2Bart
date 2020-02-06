require 'spec_helper'
require 'byebug'


module Faker
  TABLE_STUBS = {
    'person' => [{'gender' => 'M', 'birthdate' => '2000-01-01', 'birthdate_estimated' => 1}],
    'person_name' => [{'given_name' => 'Foo', 'family_name' => 'bar', 'middle_name' => nil}],
    'person_address' => [{'city_village' => 'House No. 56, Chatha Road, Chileka'}]
  }.freeze

  # Returns a fake object with a Mysql2::Client compatible interface
  def self.fake_mysqlclient(table_stubs = {})
    clazz = Class.new do
      attr_reader :table_stubs

      def initialize(table_stubs)
        @table_stubs = table_stubs
      end

      def escape(value)
        value
      end

      def query(query)
        table = /SELECT .* FROM\s+(?<table>\w*)\s+WHERE/i.match(query)[:table]
        table_stubs[table] 
      end
    end

    clazz.new(TABLE_STUBS.merge(table_stubs))
  end

  def self.fake_emastercard_patient
    {
      'patient_id' => 42,
      'guardian_name' => 'Peter Quill',
      'guardian_relation' => 'Parent',
      'guardian_phone' => '0888800900',
      'patient_phone' => '265888800900'
    }      
  end
end