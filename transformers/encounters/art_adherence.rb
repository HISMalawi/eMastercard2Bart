# frozen_string_literal: true

module Transformers
  module Encounters
    module ArtAdherence
      class << self
        def transform(patient, current_visit, previous_visit)
          {
            encounter_type_id: Nart::Encounters::ART_ADHERENCE,
            encounter_datetime: current_visit[:encounter_datetime],
            observations: art_adherence(patient, previous_visit, current_visit).reject(&:nil?)
          }
        end

        def art_adherence(patient, previous_visit, current_visit)
          unless current_visit[:pill_count]
            patient[:errors] << "Missing pill_count on #{current_visit[:encounter_datetime]}"
            return []
          end

          unless previous_visit[:weight]
            patient[:errors] << "Missing previous visit weight required for adherence on #{current_visit[:encounter_datetime]}"
            return []
          end

          number_of_drugs_prescribed = number_of_arvs_given(patient[:patient_id],
                                                            previous_visit[:encounter_datetime]) 

          if number_of_drugs_prescribed.nil? || number_of_drugs_prescribed.zero?
            # Won't log this issue here because it already is logged under
            # dispensing encounter.
            return []
          end

          drugs_prescribed_on_visit(previous_visit).map do |drug_id|
            dose = find_arvs_daily_dose(drug_id, previous_visit[:weight])
            expected_remaining_drugs = expected_remaining_arvs(dose,
                                                               number_of_drugs_prescribed,
                                                               previous_visit[:encounter_datetime],
                                                               current_visit[:encounter_datetime])

            adherence_rate = calculate_drug_adherence_rate(number_of_drugs_prescribed,
                                                           current_visit[:pill_count],
                                                           expected_remaining_drugs)

            {
              concept_id: Nart::Concepts::DRUG_ORDER_ADHERENCE,
              obs_datetime: current_visit[:encounter_datetime],
              drug_order: {
                drug_id: drug_id,
                start_date: previous_visit[:encounter_datetime]
              },
              value_numeric: adherence_rate
            }
          end
        end

        def drugs_prescribed_on_visit(visit)
          return [] if visit[:art_regimen].nil? || visit[:weight].nil?

          Transformers::Encounters::Treatment.guess_prescribed_arvs({ errors: [] },
                                                                    visit[:art_regimen],
                                                                    visit[:weight],
                                                                    visit[:encounter_datedate])
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
        def expected_remaining_arvs(drug_daily_dose, arvs_given_on_initial_visit,
                                    previous_visit_date, current_visit_date)
          number_of_days_elapsed = days_between(previous_visit_date, current_visit_date)
          arvs_given_on_initial_visit - (drug_daily_dose * number_of_days_elapsed)
        end

        # Returns total number of `regimen` pills to be taken everyday by patient
        # of given weight.
        def find_arvs_daily_dose(drug_id, weight)
          dose = Treatment.find_arv_dose(drug_id, weight)

          unless dose
            LOGGER.warn("Could find dose for drug ##{drug_id}")
            return 0
          end

          dose[:am] + dose[:pm]
        end

        def days_between(start_date, end_date)
          # Would .round be better than .to_i?
          (end_date.to_date - start_date.to_date).to_i
        end

        def calculate_drug_adherence_rate(drugs_received_on_last_visit, actual_remaining_drugs, expected_remaining_drugs)
          if drugs_received_on_last_visit == expected_remaining_drugs
            # Adherence is being estimated on same day of prescription
            return 100
          end

          actual_consumption = drugs_received_on_last_visit - actual_remaining_drugs
          expected_consumption = drugs_received_on_last_visit - expected_remaining_drugs

          (actual_consumption / expected_consumption).round(2).abs * 100
        end
      end
    end
  end
end
