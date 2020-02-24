# frozen_string_literal: true

module Transformers
  module Encounters
    module ArtAdherence
      class << self
        def transform(patient, current_visit, previous_visit)
          {
            encounter_type_id: Nart::Encounters::ART_ADHERENCE,
            encounter_datetime: current_visit[:encounter_datetime],
            observations: [art_adherence(patient, previous_visit, current_visit)].select
          }
        end

        def art_adherence(patient, previous_visit, current_visit)
          return nil unless current_visit[:pill_count]

          arvs_given = number_of_arvs_given(patient[:patient_id], previous_visit[:encounter_datetime]) 
          return nil unless arvs_given

          expected_arvs = expected_remaining_arvs(previous_visit, current_visit, arvs_given)
          return nil unless expected_arvs

          calculate_drug_adherence_rate(arvs_given, current_visit[:pill_count], expected_arvs)
        end

        # Retrieve ARV pill count for patient on a given visit
        #
        # NOTE: The visit object seems to always have pill count not set although
        #       the actual pill counts are available as observations.
        def number_of_arvs_given(patient_id, visit_date)
          obs = EmastercardDb.find_all_observations_by_encounter(patient_id,
                                                                 Emastercard::Concepts::ARVS_DISPENSED,
                                                                 Emastercard::Encounters::ART_VISIT)
                             .where(encounter_datetime: visit_date.strftime('%Y-%m-%d 00:00:00')..visit_date.strftime('%Y-%m-%d 23:59:59'))
                             .first

          return nil unless obs

          obs[:value_text]&.to_i || obs[:value_numeric]
        end

        # Calculates the expected remaining number of ARVs prescribed on initial_visit
        # as of current_visit.
        def expected_remaining_arvs(initial_visit, current_visit, arvs_given_on_initial_visit)
          daily_dose = find_arvs_daily_dose(initial_visit[:regimen], initial_visit[:weight])
          return nil unless daily_dose

          number_of_days_elapsed = days_between(initial_visit[:encounter_datetime], current_visit[:encounter_datetime])
          arvs_given_on_initial_visit - (daily_dose * number_of_days_elapsed)
        end

        # Returns total number of `regimen` pills to be taken everyday by patient
        # of given weight.
        def find_arvs_daily_dose(regimen, weight)
          arvs = Treatment.guess_prescribed_arvs(regimen, weight)
          return 0 if arvs.empty?

          dose = find_arv_dose(arv, weight)
          unless dose
            LOGGER.warn("Could find dose for regimen: #{regimen}")
            return 0
          end

          dose[:am] + dose[:pm]
        end

        def find_arv_dose(drug_id, weight)
          LOGGER.debug("Retrieving drug ##{drug_id} dose for #{weight}Kg patients")
          NartDb.from_table[:moh_regimen_dose]
                .join(:moh_regimen_ingredient, dose_id: :dose_id)
                .where(Sequel[:moh_regimen_ingredient][:drug_id] => drug_id)
                .where do
                  (Sequel[:moh_regimen_ingredient][:min_weight] <= weight)\
                  & (Sequel[:moh_regimen_ingredient][:max_weight] >= weight)
                end
                .first
        end

        def days_between(start_date, end_date)
          # Would .round be better than .to_i?
          (end_date.to_date - start_date.to_date).to_i
        end

        def calculate_drug_adherence_rate(drugs_received_on_last_visit, actual_remaining_drugs, expected_remaining_drugs)
          return 100 if actual_remaining_drugs == expected_remaining_drugs

          drugs_consumed = drugs_received_on_last_visit - actual_remaining_drugs
          doses_missed = (actual_remaining_drugs - expected_remaining_drugs)

          (drugs_consumed / doses_missed).round(2).abs * 100
        end
      end
    end
  end
end
