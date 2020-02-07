# frozen_string_literal: true

require 'app_helper'
require_relative '../../emastercard_readers/person_reader'

RSpec.describe EMastercardReaders::PersonReader do
  subject { EMastercardReaders::PersonReader }

  describe :read_person do
    let(:sequel) { Faker.emastercard_database }
    let(:seeds) { Faker.emastercard_seed_data }
    let(:patient) { sequel[:patient].first }

    it 'retrieves person details from eMastercard database' do
      person = subject.read_person(sequel, patient)

      expect(person[:birthdate]).to eq(seeds[:person].first[:birthdate])
      expect(person[:birthdate_estimated]).to eq(seeds[:person].first[:birthdate_estimated])
      expect(person[:gender]).to eq(seeds[:person].first[:gender])
      expect(person[:addresses]).to eq([{ landmark: seeds[:person_address].first[:city_village] }])
      expect(person[:names]).to eq([{ given_name: seeds[:person_name].first[:given_name],
                                      family_name: seeds[:person_name].first[:family_name],
                                      middle_name: seeds[:person_name].first[:middle_name] }])
      expect(person[:attributes]).to eq([{ person_attribute_type: 'Phone number',
                                           value: patient[:patient_phone] }])
    end

    it 'retrieves person guardian details from the eMastercard database' do
      person = subject.read_person(sequel, patient)

      relationship_type = person[:relationships].first[:relationship_type]
      guardian = person[:relationships].first[:person_b]
      guardian_name = patient[:guardian_name].split(/\s+/, 2)

      expect(relationship_type).to eq('Guardian')
      expect(guardian[:names]).to eq([{ given_name: guardian_name.first,
                                        family_name: guardian_name.last,
                                        middle_name: nil }])
      expect(guardian[:attributes]).to eq([{ person_attribute_type: 'Phone number',
                                             value: patient[:guardian_phone] }])
    end
  end
end
