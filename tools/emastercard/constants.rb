# frozen_string_literal: true

module Emastercard
  module Concepts
    ARVS_DISPENSED = 40
    CD4_COUNT = 4
    CD4_DATE = 5
    CLINICAL_REGISTRATION_TYPE = 55
    CLINICAL_REGISTRATION_ART_START_DATE = 57
    CONFIRMATORY_HIV_TEST = 17
    CPT_DISPENSED = 43
    EVER_TAKEN_ARVS = 12
    HEIGHT1 = 6 # eMastercard has 2 separate concepts for Height
    HEIGHT2 = 51
    HIV_RELATED_DISEASES = 1
    INITIAL_TB_STATUS = 9
    KS = 10
    NEXT_APPOINTMENT_DATE = 47
    OUTCOME = 48
    PILL_COUNT = 37
    PREGNANT_OR_BREASTFEEDING = 11
    WHO_STAGE = 3
  end

  module Encounters
    ART_REGISTRATION = 1
    ART_STATUS_AT_INITIATION = 2
    ART_CONFIRMATORY_TEST = 3
    ART_VISIT = 4
  end

  module PatientIdentifierTypes
    ARV_NUMBER = 4
  end
end
