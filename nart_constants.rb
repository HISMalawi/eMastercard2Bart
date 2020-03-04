# frozen_string_literal: true

module Nart
  module Concepts
    AGREES_TO_FOLLOW_UP = 2552
    AMOUNT_DISPENSED = 2834
    ART_SIDE_EFFECTS = 7755
    BREAST_FEEDING = 5632
    CD4_COUNT = 5497
    CD4_DATETIME = 6831
    CD4_LE_250 = 8262
    CD4_LE_350 = 8207
    CD4_LE_500 = 9389
    CD4_LE_750 = 8208
    CD4_LOCATION = 6830
    CONFIRMATORY_HIV_TEST_TYPE = 7880
    COTRIMOXAZOLE = 916
    CURRENT_EPISODE_OF_TB = 8206
    DATE_ANTIRETROVIRALS_STARTED = 2516
    DNA_PCR = 844
    DOLUTEGRAVIR = 9662
    DRUG_ORDER_ADHERENCE = 6987
    EVER_RECEIVED_ART = 7754
    EVER_REGISTERED_AT_ART_CLINIC = 7937
    GUARDIAN_PRESENT = 2122
    HEIGHT = 5090
    HIV_RAPID_TEST = 1040
    KAPOSIS_SARCOMA = 507
    NEXT_APPOINTMENT_DATE = 5096
    NEW_PATIENT = 7572
    NO = 1066
    ON_TB_TREATMENT = 7458
    OTHER = 6408
    PATIENT_PREGNANT = 6131
    PATIENT_PRESENT = 1805
    PRESUMED_SEVERE_HIV_IN_INFANTS = 8263
    REASON_FOR_ART_ELIGIBILITY = 7563
    TB_CONFIRMED_BUT_NOT_ON_TREATMENT = 7456
    TB_STATUS = 7459
    TB_SUSPECTED = 7455
    TB_NOT_SUSPECTED = 7454
    TYPE_OF_PATIENT = 3289
    UNKNOWN = 1067
    UNKNOWN_ARV = 5811
    VIRAL_LOAD = 856
    WEIGHT = 5089
    WHO_STAGE_1 = 9145
    WHO_STAGE_2 = 9146
    WHO_STAGE_3 = 2932
    WHO_STAGE_4 = 2933
    WHO_STAGES_CRITERIA = 2743
    YES = 1065
  end

  module Orders
    DRUG_ORDER = 1
    LAB = 4
  end

  module Encounters
    APPOINTMENT = 7
    ART_ADHERENCE = 68
    DISPENSING = 54
    HIV_CLINIC_REGISTRATION = 9
    HIV_CLINIC_CONSULTATION = 53
    HIV_RECEPTION = 51
    HIV_STAGING = 52
    REGISTRATION = 5
    TREATMENT = 25
    VITALS = 6
  end

  module PatientStates
    DEFAULTED = 12
    DIED = 3
    ON_TREATMENT = 7
    PRE_ART = 1
    TRANSFERRED_OUT = 2
    TREATMENT_STOPPED = 6
  end

  module PatientIdentifierTypes
    ARV_NUMBER = 4
  end

  module PersonAttributeTypes
    LANDMARK = 19
    PHONE_NUMBER = 12
  end

  module Programs
    HIV_PROGRAM = 1
  end

  module RelationshipTypes
    GUARDIAN = 6
  end
end
