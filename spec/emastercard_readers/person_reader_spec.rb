# frozen_string_literal: true

require 'app_helper'
require_relative '../../emastercard_readers/person_reader'

RSpec.describe EMastercardReaders::PersonReader do
  subject { EMastercardReaders::PersonReader }

  describe :read_person do
    let(:mysqlclient) { Faker.fake_mysqlclient }
    let(:table_stubs) { mysqlclient.table_stubs }
    let(:emastercard_patient) { Faker.fake_emastercard_patient }

    it 'retrieves person details from eMastercard database' do
      person = subject.read_person(mysqlclient, emastercard_patient)

      expect(person[:birthdate]).to eq(table_stubs['person'].first['birthdate'])
      expect(person[:birthdate_estimated]).to eq(table_stubs['person'].first['birthdate_estimated'])
      expect(person[:gender]).to eq(table_stubs['person'].first['gender'])
      expect(person[:addresses]).to eq([{landmark: table_stubs['person_address'].first['city_village']}])
      expect(person[:names]).to eq([{given_name: table_stubs['person_name'].first['given_name'],
                                     family_name: table_stubs['person_name'].first['family_name'],
                                     middle_name: table_stubs['person_name'].first['middle_name']}])
      expect(person[:attributes]).to eq([{person_attribute_type: 'Phone number',
                                          value: emastercard_patient['patient_phone']}])
    end

    it 'retrieves person guardian details from the eMastercard database' do
      person = subject.read_person(mysqlclient, emastercard_patient)

      relationship_type = person[:relationships].first[:relationship_type]
      guardian = person[:relationships].first[:person_b]
      guardian_name = emastercard_patient['guardian_name'].split(/\s+/, 2)

      expect(relationship_type).to eq('Guardian')
      expect(guardian[:names]).to eq([{given_name: guardian_name.first,
                                       family_name: guardian_name.last,
                                       middle_name: nil}])
      expect(guardian[:attributes]).to eq([{person_attribute_type: 'Phone number',
                                            value: emastercard_patient['guardian_phone']}])
    end
  end
end
