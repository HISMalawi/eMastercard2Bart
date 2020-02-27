# frozen_string_literal: true

require 'json'

module Transformers
  module Encounters
    module HivStaging
      class << self
        include EmastercardDb

        def transform(patient, visit)
          observations = [
            tb_status_at_initiation(patient, visit),
            reason_for_art_eligibility(patient, visit),
            *who_stages_criteria(patient, visit),
            *cd4_count(patient, visit),
            *(visit[:gender]&.casecmp?('F') ? pregnant_or_breastfeeding(patient, visit) : [nil])
          ]

          {
            encounter_type_id: Nart::Encounters::HIV_STAGING,
            encounter_datetime: visit[:encounter_datetime],
            observations: observations.reject(&:nil?)
          }
        end

        private

        def tb_status_at_initiation(patient, visit)
          case EmastercardDb.find_observation(patient[:patient_id],
                                              Emastercard::Concepts::INITIAL_TB_STATUS,
                                              Emastercard::Encounters::ART_STATUS_AT_INITIATION)
                            &.[](:value_text)
          when /Last 2years/i
            {
              concept_id: Nart::Concepts::PTB_WITHIN_LAST_2_YEARS,
              obs_datetime: visit[:encounter_datetime],
              value_coded: Nart::Concepts::YES
            }
          when /Never > 2years/i
            {
              concept_id: Nart::Concepts::PTB_WITHIN_LAST_2_YEARS,
              obs_datetime: visit[:encounter_datetime],
              value_coded: Nart::Concepts::NO
            }
          end
        end

        def pregnant_or_breastfeeding(patient, visit)
          case EmastercardDb.find_observation(patient[:patient_id],
                                              Emastercard::Concepts::PREGNANT_OR_BREASTFEEDING,
                                              Emastercard::Encounters::ART_STATUS_AT_INITIATION)
                            &.[](:value_text)
          when /bf/i
            [
              {
                concept_id: Nart::Concepts::BREAST_FEEDING,
                obs_datetime: visit[:encounter_datetime],
                value_coded: Nart::Concepts::YES
              },
              {
                concept_id: Nart::Concepts::PATIENT_PREGNANT,
                obs_datetime: visit[:encounter_datetime],
                value_coded: Nart::Concepts::NO
              },
              {
                concept_id: Nart::Concepts::REASON_FOR_ART_ELIGIBILITY,
                obs_datetime: visit[:encounter_datetime],
                value_coded: Nart::Concepts::PATIENT_PREGNANT
              }
            ]
          when /preg/i
            [
              {
                concept_id: Nart::Concepts::PATIENT_PREGNANT,
                obs_datetime: visit[:encounter_datetime],
                value_coded: Nart::Concepts::YES
              },
              {
                concept_id: Nart::Concepts::BREAST_FEEDING,
                obs_datetime: visit[:encounter_datetime],
                value_coded: Nart::Concepts::NO
              },
              {
                concept_id: Nart::Concepts::REASON_FOR_ART_ELIGIBILITY,
                obs_datetime: visit[:encounter_datetime],
                value_coded: Nart::Concepts::BREAST_FEEDING
              }
            ]
          else
            [
              {
                concept_id: Nart::Concepts::PATIENT_PREGNANT,
                obs_datetime: visit[:encounter_datetime],
                value_coded: Nart::Concepts::NO
              },
              {
                concept_id: Nart::Concepts::BREAST_FEEDING,
                obs_datetime: visit[:encounter_datetime],
                value_coded: Nart::Concepts::NO
              }
            ]
          end
        end

        WHO_STAGES_CONCEPT_MAP = {
          'clinical stage 1' => Nart::Concepts::WHO_STAGE_1,
          'clinical stage 2' => Nart::Concepts::WHO_STAGE_2,
          'clinical stage 3' => Nart::Concepts::WHO_STAGE_3,
          'clinical stage 4' => Nart::Concepts::WHO_STAGE_4
        }.freeze

        def reason_for_art_eligibility(patient, visit)
          stage = EmastercardDb.find_observation(patient[:patient_id],
                                                 Emastercard::Concepts::WHO_STAGE,
                                                 Emastercard::Encounters::ART_STATUS_AT_INITIATION)
                                &.[](:value_text)
                                &.downcase

          return nil unless stage

          concept_id = WHO_STAGES_CONCEPT_MAP[stage]
          return nil unless concept_id

          {
            concept_id: Nart::Concepts::REASON_FOR_ART_ELIGIBILITY,
            obs_datetime: visit[:encounter_datetime],
            value_coded: concept_id
          }
        end

        WHO_STAGES_CRITERIA_MAP = {
          'acute necrotizing ulcerative stomatitis, gingivitis or periodontitis' => 7546,
          'angular cheilitis' => 2575,
          'asymptomatic' => 5327,
          'atypical disseminated leishmaniasis' => 6408,
          'central nervous system toxoplasmosis' => 2583,
          'chronic cryptosporidiosis' => 7549,
          'chronic herpes simplex infection (orolabial, genital or anorectal of more than 1 month’s duration or visceral at any site)' => 5344,
          'chronic isosporiasis' => 7956,
          'cytomegalovirus infection (retinitis or infection of other organs)' => 7551,
          'disseminated mycosis (extrapulmonary histoplasmosis, coccidioidomycosis' => 7550,
          'disseminated nontuberculous mycobacterial infection' => 2585,
          'extrapulmonary cryptococcosis, including meningitis' => 7548,
          'extrapulmonary tuberculosis' => 1547,
          'fungal nail infections' => 6408,
          'herpes zoster' => 836,
          'hiv encephalopathy' => 1362,
          'hiv wasting syndrome' => 6408,
          'invasive cervical carcinoma' => 2588,
          'kaposi sarcoma' => 507,
          'lymphoma (cerebral or b-cell non-hodgkin)' => 2587,
          'moderate unexplained weight loss (<10% ofpresumed or measured body weight)' => 5332,
          'neutropaenia (<0.5 x 109/l) and/or chronic thrombocytopaenia (<50 x 109/l)' => 7954,
          'oesophageal candidiasis (or candidiasis of trachea, bronchi or lungs)' => 5340,
          'oral hairy leukoplakia' => 5337,
          'papular pruritic eruption' => 7536,
          'persistent generalized lymphadenopathy' => 5328,
          'persistent oral candidiasis' => 5334,
          'pneumocystis (jirovecii) pneumonia' => 882,
          'progressive multifocal leukoencephalopathy' => 5046,
          'pulmonary tuberculosis' => 8206,
          'recurrent oral ulceration' => 2576,
          'recurrent respiratory tract infections (sinusitis tonsillitis, otitis media, pharyngitis)' => 5012,
          'recurrent septicaemia (including nontyphoidal Salmonella)' => 7959,
          'recurrent severe bacterial pneumonia' => 1215,
          'seborrhoeic dermatitis' => 2578,
          'severe bacterial infections (such as pneumonia, empyema, pyomyositis, bone or joint infection, meningitis, bacteraemia)' => 2894,
          'Symptomatic hiv-associated nephropathy or cardiomyopathy' => 7957,
          'toxoplasmosis of the brain (from age 1 month)' => 5048,
          'tuberculosis (ptb or eptb) within the last 2 years' => 7539,
          'unexplained anaemia (<8 g/dl)' => 2582,
          'unexplained chronic diarrhoea for longer than 1 month' => 5018,
          'unexplained persistent fever (intermittent or constant for longer than 1 month)' => 5027,
          'unexplained severe weight loss (>10% of presumed or measured body weight)' => 7540
        }.freeze

        def who_stages_criteria(patient, visit)
          diseases = EmastercardDb.find_observation(patient[:person_id],
                                                    Emastercard::Concepts::HIV_RELATED_DISEASES,
                                                    Emastercard::Encounters::ART_STATUS_AT_INITIATION)
                                  &.[](:value_text)
                                  &.downcase
          return nil unless diseases

          JSON.parse(diseases).map do |disease|
            disease = disease['value']
            disease_concept_id = WHO_STAGES_CRITERIA_MAP[disease] || Nart::Concepts::OTHER
            {
              concept_id: Nart::Concepts::WHO_STAGES_CRITERIA,
              obs_datetime: visit[:encounter_datetime],
              value_coded: disease_concept_id
            }
          end
        end

        # Capture CD4 level and also set reason for starting if CD4 level is below threshold
        #
        # WARNING: This is one hideous ball of mud!
        def cd4_count(patient, visit)
          cd4_obs = EmastercardDb.find_observation(patient[:patient_id],
                                                   Emastercard::Concepts::CD4_COUNT,
                                                   Emastercard::Encounters::ART_STATUS_AT_INITIATION)
          return nil unless cd4_obs

          cd4_value = cd4_obs[:value_numeric] || cd4_obs[:value_text]&.to_f
          return unless cd4_value

          observations = []

          # Capture CD4 level thresholds and save reason for starting if necessary.
          is_reason_for_starting_set = false

          [Nart::Concepts::CD4_LE_250, Nart::Concepts::CD4_LE_350, Nart::Concepts::CD4_LE_500,
           Nart::Concepts::CD4_LE_750].each do |threshold|
            is_cd4_count_below_threshold = cd4_count_below_threshold?(cd4_value, threshold)

            if is_cd4_count_below_threshold && !is_reason_for_starting_set
              observations << {
                concept_id: Nart::Concepts::REASON_FOR_ART_ELIGIBILITY,
                obs_datetime: visit[:encounter_datetime],
                value_coded: threshold
              }
              is_reason_for_starting_set = false
            end

            observations << {
              concept_id: threshold,
              obs_datetime: visit[:encounter_datetime],
              value_coded: is_cd4_count_below_threshold ? Nart::Concepts::YES : Nart::Concepts::NO
            }
          end

          # Capture CD4 count raw value
          cd4_date = EmastercardDb.find_observation(patient[:patient_id],
                                                    Emastercard::Concepts::CD4_DATE,
                                                    Emastercard::Encounters::ART_STATUS_AT_INITIATION)

          observations.append(
            {
              concept_id: Nart::Concepts::CD4_COUNT,
              obs_datetime: visit[:encounter_datetime],
              value_numeric: cd4_value
            },
            {
              concept_id: Nart::Concepts::CD4_DATETIME,
              obs_datetime: visit[:encounter_datetime],
              value_datetime: cd4_date&.[](:value_datetime),
              comments: cd4_date&.[](:value_datetime)&.nil? ? 'Not provided in emastercard' : nil
            }
          )

          observations
        end

        def cd4_count_below_threshold?(cd4_value, threshold)
          (cd4_value <= 250 && threshold == Nart::Concepts::CD4_LE_250)\
          || (cd4_value <= 350 && threshold == Nart::Concepts::CD4_LE_350)\
          || (cd4_value <= 500 && threshold == Nart::Concepts::CD4_LE_500)\
          || (cd4_value <= 750 && threshold == Nart::Concepts::CD4_LE_750)
        end
      end
    end
  end
end
