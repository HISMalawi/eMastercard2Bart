# frozen_string_literal: true

require 'json'

module Transformers
  module Encounters
    module HivStaging
      class << self
        include EmastercardDb

        def transform(patient, registration_encounter)
          observations = [
            tb_status_at_initiation(patient, registration_encounter),
            reason_for_art_eligibility(patient, registration_encounter),
            kaposis_sarcoma(patient, registration_encounter),
            *who_stages_criteria(patient, registration_encounter),
            *cd4_count(patient, registration_encounter),
            *(registration_encounter[:gender]&.casecmp?('F') ? pregnant_or_breastfeeding(patient, registration_encounter) : [nil])
          ].reject(&:nil?)

          unless observations.any? { |obs| reason_for_starting_set?(obs) }
            observations << unknown_reason_for_starting_art(patient, registration_encounter)
          end

          {
            encounter_type_id: Nart::Encounters::HIV_STAGING,
            encounter_datetime: registration_encounter[:encounter_datetime],
            observations: observations
          }
        end

        private

        def tb_status_at_initiation(patient, registration_encounter)
          case EmastercardDb.find_observation(patient[:patient_id],
                                              Emastercard::Concepts::INITIAL_TB_STATUS,
                                              Emastercard::Encounters::ART_STATUS_AT_INITIATION)
                            &.[](:value_text)
          when /Last 2(yrs|years)/i
            {
              concept_id: Nart::Concepts::WHO_STAGES_CRITERIA,
              obs_datetime: registration_encounter[:encounter_datetime],
              value_coded: Nart::Concepts::PTB_WITHIN_LAST_2_YEARS
            }
          when /Curr/i
            {
              concept_id: Nart::Concepts::WHO_STAGES_CRITERIA,
              obs_datetime: registration_encounter[:encounter_datetime],
              value_coded: Nart::Concepts::CURRENT_EPISODE_OF_TB
            }
          when /Never > 2years/i
            # This isn't explicitly saved in NART
            nil
          else
            patient[:errors] << "Missing TB status initiation on #{registration_encounter[:encounter_datetime]}"
            nil
          end
        end

        def pregnant_or_breastfeeding(patient, registration_encounter)
          case EmastercardDb.find_observation(patient[:patient_id],
                                              Emastercard::Concepts::PREGNANT_OR_BREASTFEEDING,
                                              Emastercard::Encounters::ART_STATUS_AT_INITIATION)
                            &.[](:value_text)
          when /bf/i
            [
              {
                concept_id: Nart::Concepts::BREAST_FEEDING,
                obs_datetime: registration_encounter[:encounter_datetime],
                value_coded: Nart::Concepts::YES
              },
              {
                concept_id: Nart::Concepts::PATIENT_PREGNANT,
                obs_datetime: registration_encounter[:encounter_datetime],
                value_coded: Nart::Concepts::NO
              },
              {
                concept_id: Nart::Concepts::REASON_FOR_ART_ELIGIBILITY,
                obs_datetime: registration_encounter[:encounter_datetime],
                value_coded: Nart::Concepts::PATIENT_PREGNANT
              }
            ]
          when /preg/i
            [
              {
                concept_id: Nart::Concepts::PATIENT_PREGNANT,
                obs_datetime: registration_encounter[:encounter_datetime],
                value_coded: Nart::Concepts::YES
              },
              {
                concept_id: Nart::Concepts::BREAST_FEEDING,
                obs_datetime: registration_encounter[:encounter_datetime],
                value_coded: Nart::Concepts::NO
              },
              {
                concept_id: Nart::Concepts::REASON_FOR_ART_ELIGIBILITY,
                obs_datetime: registration_encounter[:encounter_datetime],
                value_coded: Nart::Concepts::BREAST_FEEDING
              }
            ]
          else
            [
              {
                concept_id: Nart::Concepts::PATIENT_PREGNANT,
                obs_datetime: registration_encounter[:encounter_datetime],
                value_coded: Nart::Concepts::NO
              },
              {
                concept_id: Nart::Concepts::BREAST_FEEDING,
                obs_datetime: registration_encounter[:encounter_datetime],
                value_coded: Nart::Concepts::NO
              }
            ]
          end
        end

        WHO_STAGES_CONCEPT_MAP = {
          'clinical stage 1' => Nart::Concepts::WHO_STAGE_1,
          'clinical stage 2' => Nart::Concepts::WHO_STAGE_2,
          'clinical stage 3' => Nart::Concepts::WHO_STAGE_3,
          'clinical stage 4' => Nart::Concepts::WHO_STAGE_4,
          'pshd' => Nart::Concepts::PRESUMED_SEVERE_HIV_IN_INFANTS
        }.freeze

        def reason_for_art_eligibility(patient, registration_encounter)
          stage = EmastercardDb.find_observation(patient[:patient_id],
                                                 Emastercard::Concepts::WHO_STAGE,
                                                 Emastercard::Encounters::ART_STATUS_AT_INITIATION)
                                &.[](:value_text)
                                &.downcase

          unless stage
            patient[:errors] << "Missing who_stage on #{registration_encounter[:encounter_datetime]}"
            return nil
          end

          concept_id = WHO_STAGES_CONCEPT_MAP[stage]
          unless concept_id
            patient[:errors] << "Unknown who_stage 'stage' on #{registration_encounter[:encounter_datetime]}"
            return nil
          end

          if concept_id == Nart::Concepts::WHO_STAGE_2
            birthdate = patient[:birthdate]

            if birthdate.nil?
              concept_id = Nart::Concepts::WHO_STAGE_2
            elsif (registration_encounter[:encounter_datetime].to_date - birthdate.to_date).to_i < 14
              concept_id = Nart::Concepts::WHO_STAGE_2_PAEDS
            else
              concept_id = Nart::Concepts::WHO_STAGE_2_ADULTS
            end
          end

          {
            concept_id: Nart::Concepts::REASON_FOR_ART_ELIGIBILITY,
            obs_datetime: registration_encounter[:encounter_datetime],
            value_coded: concept_id
          }
        end

        def kaposis_sarcoma(patient, registration_encounter)
          observation = EmastercardDb.find_all_observations_by_encounter(patient[:patient_id],
                                                                         Emastercard::Concepts::KS,
                                                                         Emastercard::Encounters::ART_STATUS_AT_INITIATION)
                                     .exclude(value_text: nil)
                                     .first

          return nil unless observation&.[](:value_text)&.casecmp?('Y')

          {
            concept_id: Nart::Concepts::WHO_STAGES_CRITERIA,
            obs_datetime: registration_encounter[:encounter_datetime],
            value_coded: Nart::Concepts::KAPOSIS_SARCOMA,
            comments: "Transformed from eMastercard's KS"
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

        def who_stages_criteria(patient, registration_encounter)
          diseases = EmastercardDb.find_observation(patient[:patient_id],
                                                    Emastercard::Concepts::HIV_RELATED_DISEASES,
                                                    Emastercard::Encounters::ART_STATUS_AT_INITIATION)
                                  &.[](:value_text)
                                  &.downcase

          unless diseases
            patient[:errors] << "Missing hiv_related_diseases on #{registration_encounter[:encounter_datetime]}"
            return nil
          end

          JSON.parse(diseases).map do |disease|
            disease = disease['value']
            disease_concept_id = WHO_STAGES_CRITERIA_MAP[disease] || Nart::Concepts::OTHER
            {
              concept_id: Nart::Concepts::WHO_STAGES_CRITERIA,
              obs_datetime: registration_encounter[:encounter_datetime],
              value_coded: disease_concept_id,
              comments: "Transformed from eMastercard's #{disease}"
            }
          end
        end

        # Capture CD4 level and also set reason for starting if CD4 level is below threshold
        #
        # WARNING: This is one hideous ball of mud!
        def cd4_count(patient, registration_encounter)
          cd4_obs = EmastercardDb.find_observation(patient[:patient_id],
                                                   Emastercard::Concepts::CD4_COUNT,
                                                   Emastercard::Encounters::ART_STATUS_AT_INITIATION)
          unless cd4_obs
            patient[:errors] << "Missing cd4_count on #{registration_encounter[:encounter_datetime]}"
            return nil
          end

          cd4_value = cd4_obs[:value_numeric] || cd4_obs[:value_text]&.to_f
          unless cd4_value
            patient[:errors] << "Missing cd4_count on #{registration_encounter[:encounter_datetime]}"
            return nil
          end

          observations = []

          # Capture CD4 level thresholds and save reason for starting if necessary.
          is_reason_for_starting_set = false

          [Nart::Concepts::CD4_LE_250, Nart::Concepts::CD4_LE_350, Nart::Concepts::CD4_LE_500,
           Nart::Concepts::CD4_LE_750].each do |threshold|
            is_cd4_count_below_threshold = cd4_count_below_threshold?(cd4_value, threshold)

            if is_cd4_count_below_threshold && !is_reason_for_starting_set
              observations << {
                concept_id: Nart::Concepts::REASON_FOR_ART_ELIGIBILITY,
                obs_datetime: registration_encounter[:encounter_datetime],
                value_coded: threshold
              }
              is_reason_for_starting_set = false
            end

            observations << {
              concept_id: threshold,
              obs_datetime: registration_encounter[:encounter_datetime],
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
              obs_datetime: registration_encounter[:encounter_datetime],
              value_numeric: cd4_value
            },
            {
              concept_id: Nart::Concepts::CD4_DATETIME,
              obs_datetime: registration_encounter[:encounter_datetime],
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

        def unknown_reason_for_starting_art(_patient, registration_encounter)
          {
            concept_id: Nart::Concepts::REASON_FOR_ART_ELIGIBILITY,
            obs_datetime: registration_encounter[:encounter_datetime],
            value_coded: Nart::Concepts::UNKNOWN,
            comments: 'Patient had no reason for starting in eMastercard'
          }
        end

        def reason_for_starting_set?(obs)
          obs[:concept_id] == Nart::Concepts::REASON_FOR_ART_ELIGIBILITY
        end
      end
    end
  end
end
