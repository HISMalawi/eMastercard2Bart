# frozen_string_literal: true

module Emastercard
  module Concepts
    ARVS_DISPENSED = 40
    CLINICAL_REGISTRATION_TYPE = 55
    CLINICAL_REGISTRATION_ART_START_DATE = 57
    EVER_TAKEN_ARVS = 12
    HEIGHT1 = 6 # eMastercard has 2 separate concepts for Height
    HEIGHT2 = 51
    INITIAL_TB_STATUS = 9
    KS = 10
    NEXT_APPOINTMENT_DATE = 47
    PILL_COUNT = 37
  end

  module Encounters
    ART_REGISTRATION = 1
    ART_VISIT = 4
  end

  module PatientIdentifierTypes
    ARV_NUMBER = 4
  end
end
