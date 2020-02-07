# frozen_string_literal: true

module EMastercard
  SEED_DATA = {
    patient: [{ guardian_name: 'Peter Quill', guardian_relation: 'Parent',
                guardian_phone: '0888800900', patient_phone: '265888800900',
                patient_id: 1 }],
    person: [{ person_id: 1, gender: 'M', birthdate: Date.strptime('2000-01-01'), birthdate_estimated: true }],
    person_name: [{ person_id: 1, given_name: 'Foo', family_name: 'bar', middle_name: nil }],
    person_address: [{ person_id: 1, city_village: 'House No. 56, Chatha Road, Chileka' }]
  }.freeze

  # Bless a sequel database with a test emastercard schema
  def self.create_database_schema(sequel)
    sequel.create_table(:patient) do
      primary_key :patient_id
      String :guardian_name
      String :patient_phone
      String :guardian_phone
      String :follow_up
      String :guardian_relation
      TrueClass :soldier
    end

    sequel.create_table(:person) do
      primary_key :person_id
      String :uuid
      String :gender
      Date :birthdate
      TrueClass :birthdate_estimated
      TrueClass :dead
      Integer :cause_of_death
    end

    sequel.create_table(:person_name) do
      primary_key :person_name_id
      String :uuid
      Integer :person_id
      String :given_name
      String :family_name
      String :middle_name
    end

    sequel.create_table(:person_address) do
      primary_key :person_address_id
      String :uuid
      Integer :person_id
      String :city_village
    end
  end

  def self.seed_database(sequel, data = {})
    SEED_DATA.merge(data).each do |table, rows|
      rows.each { |row| sequel[table].insert(row) }
    end
  end
end
