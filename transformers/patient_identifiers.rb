# frozen_string_literal: true

module Transformers
  module PatientIdentifiers
    def self.transform(patient)
      arv_number = find_arv_number(patient)
      return [] unless arv_number

      [
        {
          identifier_type: Nart::PatientIdentifierTypes::ARV_NUMBER,
          identifier: arv_number
        }
      ]
    end

    def self.find_arv_number(patient)
      identifier = EmastercardDb.from_table[:patient_identifier]
                                .first(patient_id: patient[:patient_id],
                                       identifier_type: Emastercard::PatientIdentifierTypes::ARV_NUMBER,
                                       voided: 0)
      return nil unless identifier

      "ARV-#{CONFIG['site_prefix']}-#{identifier[:identifier]}"
    end
  end
end
