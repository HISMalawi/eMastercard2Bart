# frozen_string_literal: true
require 'set'

module Transformers
  module Encounters
    module Treatment
      class << self
        def transform(patient, visit = nil)
          regimen, drugs, visit_date = visit ? find_regimen(patient, visit) : find_initial_regimen(patient)

          observations = []

          if regimen
            observations << {
              concept_id: Nart::Concepts::ARV_REGIMEN,
              obs_datetime: visit_date, value_text: regimen
            }
          end

          {
            encounter_type_id: Nart::Encounters::TREATMENT,
            encounter_datetime: visit_date,
            observations: observations,
            orders: drugs.map do |drug_id|
              dose = find_arv_dose(drug_id, visit&.[](:weight))

              {
                order_type_id: Nart::Orders::DRUG_ORDER,
                concept_id: drug_concept_id(drug_id),
                start_date: visit_date,
                auto_expire_date: nil, # Can this be safely estimated from  pills given?
                drug_order: {
                  drug_inventory_id: drug_id,
                  equivalent_daily_dose: dose && (dose[:am] || 0 + dose[:pm] || 0)
                }
              }
            end
          }
        end

        def find_regimen(patient, visit)
          regimen = visit[:art_regimen]&.strip
          visit_date = visit[:encounter_datetime]
          drugs = regimen ? guess_prescribed_arvs(patient, regimen, visit[:weight], visit_date) : []

          if visit[:cpt_ipt_given_options]&.casecmp?('Yes')
            drugs = [*drugs, guess_prescribed_cpt(visit[:weight])]
          end

          [regimen, drugs, visit_date]
        end

        def find_initial_regimen(patient)
          regimen = patient_initial_art_regimen(patient[:patient_id])
          regimen_date = patient_initial_art_regimen_date(patient[:patient_id])

          return [nil, [], nil] unless regimen && regimen_date
 
          drugs = guess_prescribed_arvs(patient, regimen, nil, regimen_date)

          [regimen, drugs, regimen_date]
        end

        def patient_initial_art_regimen(patient_id)
          EmastercardDb.from_table[:obs]
                       .join(:encounter, encounter_id: :encounter_id)
                       .where(concept_id: Emastercard::Concepts::INITIAL_ART_REGIMEN,
                              patient_id: patient_id,
                              Sequel[:encounter][:encounter_type] => Emastercard::Encounters::ART_CONFIRMATORY_TEST)
                       .exclude(value_text: nil)
                       .select(:value_text)
                       .first
                       &.[](:value_text)
        end

        def patient_initial_art_regimen_date(patient_id)
          EmastercardDb.from_table[:obs]
                       .join(:encounter, encounter_id: :encounter_id)
                       .where(concept_id: Emastercard::Concepts::INITIAL_ART_REGIMEN_START_DATE,
                              patient_id: patient_id,
                              Sequel[:encounter][:encounter_type] => Emastercard::Encounters::ART_CONFIRMATORY_TEST)
                       .exclude(value_datetime: nil)
                       .select(:value_datetime)
                       .first
                       &.[](:value_datetime)
        end

        def find_arv_dose(drug_id, weight)
          LOGGER.debug("Retrieving drug ##{drug_id} dose for #{weight}Kg patients")
          NartDb.from_table[:moh_regimen_doses]
                .join(:moh_regimen_ingredient, dose_id: :dose_id)
                .where(Sequel[:moh_regimen_ingredient][:drug_inventory_id] => drug_id)
                .where(Sequel.lit('CAST(min_weight AS DECIMAL(4, 1)) <= :weight
                                   AND CAST(max_weight AS DECIMAL(4, 1)) >= :weight',
                                  weight: weight&.round(1)))
                .first
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
          13 => [Set.new([983]).freeze],
          14 => [Set.new([984, 982])],
          15 => [Set.new([969, 982])],
          16 => [Set.new([1043, 1044]), Set.new([954, 969])],
          17 => [Set.new([30, 1044]), Set.new([11, 969])]
        }.freeze

        def guess_prescribed_arvs(patient, regimen_name, patient_weight, date)
          LOGGER.debug("Guestimating ARV prescription for #{patient_weight}Kg patient under regimen #{regimen_name}")
          if regimen_name.nil?
            patient[:errors] << "Missing art_regimen on #{date}"
            return []
          elsif regimen_name.casecmp?('Other')
            return [Nart::Drugs::UNKNOWN_ARV]
          end

          regimen_index, _regimen_category = split_regimen_name(regimen_name)
          unless regimen_index
            patient[:errors] << "Invalid regimen name '#{regimen_name}' on #{date}"
            return []
          end

          return prescribe_legacy_arvs(regimen_name) if [1, 3].include?(regimen_index)

          if patient_weight.nil?
            LOGGER.warn("Patient weight not available, choosing first combination of #{regimen_index}")
            return REGIMEN_COMBINATIONS[regimen_index]&.first || []
          end

          regimen_id = NartDb.from_table[:moh_regimens]
                             .where(regimen_index: regimen_index)
                             .get(:regimen_id)

          drugs = NartDb.from_table[:moh_regimen_ingredient]
                        .where(regimen_id: regimen_id)
                        .where(Sequel.lit('CAST(min_weight AS DECIMAL(4, 1)) <= :weight
                                           AND CAST(max_weight AS DECIMAL(4, 1)) >= :weight',
                                          weight: patient_weight&.round(1)))
                        .map(:drug_inventory_id)

          if drugs.empty?
            patient[:errors] << "Non standard regimen #{regimen_name} for patient of weight #{patient_weight} on #{date}"
            return []
          end

          drug_combinations = form_regimen_combinations(regimen_index, drugs)
          if drug_combinations.size > 1
            LOGGER.warn("Weight, #{patient_weight}Kg, has multiple possible drugs on regimen #{regimen_name}: #{drug_combinations}")
          end

          drug_combinations.first || []
        end

        def prescribe_legacy_arvs(regimen_name)
          case regimen_name
          when '1A' then [613]
          when '1P' then [72]
          else [955] # Assuming that 3A or 3P
          end
        end

        def guess_prescribed_cpt(patient_weight)
          LOGGER.debug("Guestimating CPT prescription for #{patient_weight}Kg patient")
          return cpt_drug_ids.first if patient_weight.nil?

          # Make sure we get only the cpt for patients with the given weight
          NartDb.from_table[:moh_regimen_ingredient]
                .where(drug_inventory_id: cpt_drug_ids)
                .where(Sequel.lit('CAST(min_weight AS DECIMAL(4, 1)) <= :weight
                                   AND CAST(max_weight AS DECIMAL(4, 1)) >= :weight',
                                  weight: patient_weight&.round(1)))
                .get(:drug_inventory_id)
        end

        def drug_concept_id(drug_id)
          return Nart::Concepts::UNKNOWN_ARV unless drug_id

          @drug_concept_ids ||= {}
          return @drug_concept_ids[drug_id] if @drug_concept_ids.include?(drug_id)

          @drug_concept_ids[drug_id] = NartDb.from_table[:drug]
                                             .where(drug_id: drug_id)
                                             .get(:concept_id)
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
          @cpt_drug_ids ||= NartDb.from_table[:drug]
                                  .where(concept_id: cpt_concept_id, retired: 0)
                                  .map(:drug_id)
        end

        def cpt_concept_id
          916
        end
      end
    end
  end
end
