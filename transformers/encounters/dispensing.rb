# frozen_string_literal: true

module Transformers
  module Encounters
    module Dispensing
      class << self
        def transform(patient, visit, treatment_encounter)
          observations = treatment_encounter[:orders].map do |order|
            amount_dispensed = find_drug_amount_dispensed(order[:drug_order][:drug_inventory_id], visit)
            next nil unless amount_dispensed

            if order[:drug_order][:equivalent_daily_dose]&.positive?
              daily_dose = amount_dispensed / order[:drug_order][:equivalent_daily_dose]
              order[:auto_expire_date] = order[:start_date] + daily_dose
            end

            order[:drug_order][:quantity] = amount_dispensed

            {
              concept_id: Nart::Concepts::AMOUNT_DISPENSED,
              obs_datetime: visit[:encounter_datetime],
              value_drug: order[:drug_order][:drug_inventory_id],
              value_numeric: amount_dispensed
            }
          end

          {
            encounter_type_id: Nart::Encounters::DISPENSING,
            encounter_datetime: visit[:encounter_datetime],
            observations: observations.reject(&:nil?)
          }
        end

        def find_drug_amount_dispensed(drug_id, visit)
          concept_id = if drug_id == Nart::Concepts::COTRIMOXAZOLE
                         Emastercard::Concepts::CPT_DISPENSED
                       else
                         Emastercard::Concepts::ARVS_DISPENSED
                       end

          start_date = visit[:encounter_datetime].strftime('%Y-%m-%d 00:00:00')
          end_date = visit[:encounter_datetime].strftime('%Y-%m-%d 23:59:59')

          observation = EmastercardDb.from_table[:obs]
                                     .join(:encounter, encounter_id: :encounter_id)
                                     .where(Sequel[:encounter][:encounter_datetime] => start_date..end_date,
                                            concept_id: concept_id,
                                            person_id: visit[:person_id])
                                     .select(:value_numeric, :value_text)
                                     .first

          return nil unless observation

          observation[:value_numeric] || observation[:value_text]&.to_i
        end
      end
    end
  end
end
