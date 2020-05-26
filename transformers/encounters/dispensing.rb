# frozen_string_literal: true

module Transformers
  module Encounters
    module Dispensing
      class << self
        def transform(patient, visit, treatment_encounter)
          observations = treatment_encounter[:orders].map do |order|
            drug_id = order[:drug_order][:drug_inventory_id]
            amount_dispensed = find_drug_amount_dispensed(patient, drug_id, visit)

            unless amount_dispensed
              patient[:errors] << "No amount dispensed for drug ##{drug_id} on #{visit[:encounter_datetime]}"
              next nil
            end

            if order[:drug_order][:equivalent_daily_dose]&.positive?
              daily_dose = amount_dispensed / order[:drug_order][:equivalent_daily_dose]
              # Cast to datetime to enable date arithmetic
              order[:auto_expire_date] = order[:start_date].to_datetime + daily_dose
            end

            order[:drug_order][:quantity] = amount_dispensed

            {
              concept_id: Nart::Concepts::AMOUNT_DISPENSED,
              obs_datetime: retro_date(visit[:encounter_datetime]),
              value_drug: drug_id,
              value_numeric: amount_dispensed
            }
          end

          {
            encounter_type_id: Nart::Encounters::DISPENSING,
            encounter_datetime: retro_date(visit[:encounter_datetime]),
            observations: observations.reject(&:nil?)
          }
        end

        def find_drug_amount_dispensed(patient, drug_id, visit)
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

          unless observation
            patient[:errors] << "Missing amount_dispensed for ARV or CPT on #{visit[:encounter_datetime]}"
            return nil
          end

          amount_dispensed = observation[:value_numeric] || observation[:value_text]&.to_i
          unless amount_dispensed
            patient[:errors] << "Missing amount_dispensed for ARV or CPT on #{visit[:encounter_datetime]}"
            return nil
          end

          amount_dispensed
        end
      end
    end
  end
end
