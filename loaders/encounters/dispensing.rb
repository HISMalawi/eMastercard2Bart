# frozen_string_literal: true

module Loaders
  module Encounters
    module Dispensing
      class << self
        def load(patient, visit, treatment_encounter)
          {
            encounter_type_id: Nart::Encounters::DISPENSING,
            encounter_datetime: visit[:encounter_datetime],
            orders: treatment_encounter[:orders].map do |order|
              {
                concept_id: Nart::Concepts::AMOUNT_DISPENSED,
                obs_datetime: visit[:encounter_datetime],
                value_drug: order[:concept_id],
                value_coded: if order[:concept_id] == Nart::Concepts::COTRIMOXAZOLE
                               patient[:cpt_ipt_given_no_of_tablets]
                             else
                               patient[:arvs_given_no_of_tablets]
                             end
              }
            end
          }
        end
      end
    end
  end
end
