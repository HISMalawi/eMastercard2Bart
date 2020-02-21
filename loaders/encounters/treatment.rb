# frozen_string_literal: true
require 'set'

module Loaders
  module Encounters
    module Treatment
      class << self
        include NartDbUtils

        def load(_patient, visit)
          visit_date = visit[:encounter_datetime]
          drugs = guess_prescribed_arvs(visit[:art_regimen], visit[:weight], visit_date)

          if visit[:cpt_ipt_given_options]&.casecmp?('Yes')
            drugs << guess_prescribed_cpt(visit[:weight])
          end

          {
            encounter_type_id: Nart::Encounters::TREATMENT,
            encounter_datetime: visit[:encounter_datetime],
            orders: drugs.map do |drug_id|
              {
                order_type_id: Nart::Orders::DRUG_ORDER,
                concept_id: drug_concept_id(drug_id),
                start_date: visit_date,
                auto_expire_date: nil, # Can this be safely estimated from  pills given?
                drug_order: {
                  drug_inventory_id: drug_id
                }
              }
            end
          }
        end

        REGIMEN_COMBINATIONS = {
          # ABC/3TC (Abacavir and Lamivudine 60/30mg tablet) = 733
          # NVP (Nevirapine 50 mg tablet) = 968
          # NVP (Nevirapine 200 mg tablet) = 22
          # ABC/3TC (Abacavir and Lamivudine 600/300mg tablet) = 969
          # AZT/3TC/NVP (60/30/50mg tablet) = 732
          # AZT/3TC/NVP (300/150/200mg tablet) = 731
          # AZT/3TC (Zidovudine and Lamivudine 60/30 tablet) = 736
          # EFV (Efavirenz 200mg tablet) = 30
          # EFV (Efavirenz 600mg tablet) = 11
          # AZT/3TC (Zidovudine and Lamivudine 300/150mg) = 39
          # TDF/3TC/EFV (300/300/600mg tablet) = 735
          # TDF/3TC (Tenofavir and Lamivudine 300/300mg tablet = 734
          # ATV/r (Atazanavir 300mg/Ritonavir 100mg) = 932
          # LPV/r (Lopinavir and Ritonavir 100/25mg tablet) = 74
          # LPV/r (Lopinavir and Ritonavir 200/50mg tablet) = 73
          # Darunavir 600mg = 976
          # Ritonavir 100mg = 977
          # Etravirine 100mg = 978
          # RAL (Raltegravir 400mg) = 954
          # NVP (Nevirapine 200 mg tablet) = 22
          # LPV/r pellets = 979
          0 => [Set.new([1044, 968]), Set.new([1044, 22]), Set.new([969, 22]), Set.new([969, 968])],
          2 => [Set.new([732]), Set.new([732, 736]), Set.new([732, 39]), Set.new([731]), Set.new([731, 39]), Set.new([731, 736])],
          4 => [Set.new([736, 30]), Set.new([736, 11]), Set.new([39, 11]), Set.new([39, 30])],
          5 => [Set.new([735])],
          6 => [Set.new([734, 22])],
          7 => [Set.new([734, 932])],
          8 => [Set.new([39, 932])],
          9 => [Set.new([1044, 979]), Set.new([1044, 74]), Set.new([1044, 73]), Set.new([969, 73]), Set.new([969, 74])],
          10 => [Set.new([734, 73])],
          11 => [Set.new([736, 74]), Set.new([736, 73]), Set.new([736, 1044]), Set.new([39, 73]), Set.new([39, 74])],
          12 => [Set.new([976, 977, 982])],
          13 => [Set.new([983])],
          14 => [Set.new([984, 982])],
          15 => [Set.new([969, 982])],
          16 => [Set.new([1043, 1044]), Set.new([954, 969])],
          17 => [Set.new([30, 1044]), Set.new([11, 969])]
        }.freeze

        def guess_prescribed_arvs(regimen_name, patient_weight, _date)
          LOGGER.debug("Guestimating ARV prescription for #{patient_weight}Kg patient under regimen #{regimen_name}")
          return [] unless regimen_name

          regimen_index, _regimen_category = split_regimen_name(regimen_name)
          return [] unless regimen_index

          if patient_weight.nil?
            LOGGER.warn("Patient weight not available, choosing first combination of #{regimen_index}")
            return REGIMEN_COMBINATIONS[regimen_name]&.first || []
          end

          regimen_id = sequel[:moh_regimens].where(regimen_index: regimen_index)
                                            .get(:regimen_id)
          drugs = sequel[:moh_regimen_ingredient].where(regimen_id: regimen_id)
                                                 .where { min_weight <= patient_weight && min_weight >= patient_weight }
                                                 .map(:drug_inventory_id)

          return [] if drugs.empty?

          drug_combinations = form_regimen_combinations(regimen_index, drugs)
          if drug_combinations.size > 1
            LOGGER.warn("Weight, #{patient_weight}Kg, has multiple possible drugs on regimen #{regimen_name}: #{drug_combinations}")
          end

          drug_combinations.first || []
        end

        def guess_prescribed_cpt(patient_weight)
          LOGGER.debug("Guestimating CPT prescription for #{patient_weight}Kg patient")
          return cpt_drug_ids.first if patient_weight.nil?

          # Make sure we get only the cpt for patients with the given weight
          sequel[:moh_regimen_ingredient].where(drug_inventory_id: cpt_drug_ids)
                                         .where { min_weight <= patient_weight && max_weight >= patient_weight }
                                         .get(:drug_inventory_id)
        end

        def drug_concept_id(drug_id)
          @drug_concept_ids ||= {}
          return @drug_concept_ids[drug_id] if @drug_concept_ids.include?(drug_id)

          @drug_concept_ids[drug_id] = sequel[:drug].where(drug_id: drug_id).get(:concept_id)
        end

        def split_regimen_name(regimen_name)
          match = /(\d+)([AP])/.match(regimen_name)
          return [nil, nil] unless match

          [match[1].to_i, match[2]]
        end

        def form_regimen_combinations(regimen_index, drugs)
          combinations = Set.new

          (0...drugs.size).each do |pivot|
            (pivot...drugs.size).each do |combo_start|
              (combo_start..drugs.size).each do |combo_end|
                trial_regimen = Set.new([drugs[pivot], *drugs[combo_start...combo_end]])

                next unless valid_regimen_combination?(regimen_index, trial_regimen)

                combinations << trial_regimen
              end
            end
          end

          combinations
        end

        def valid_regimen_combination?(regimen_index, drug_combination)
          REGIMEN_COMBINATIONS[regimen_index]&.include?(drug_combination)
        end

        def cpt_drug_ids
          @cpt_drug_ids ||= sequel[:drug].where(concept_id: cpt_concept_id, retired: 0)
                                         .map(:drug_id)
        end

        def cpt_concept_id
          916
        end
      end
    end
  end
end
