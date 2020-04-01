#!/bin/bash

echo "Starting migration..."
ruby main.rb

echo -e "\n\nRunning migrated patients report..."
ruby comparatives/patients_migrated.rb

echo -e "\n\nRunning patients without visits report..."
ruby comparatives/patients_without_visits.rb

echo -e "\n\nRunning patients with outcome on initial visit report..."
ruby comparatives/patients_with_outcome_on_initial_visit.rb

echo -e "\n\nRunning patients without drug dispensations report..."
ruby comparatives/patients_without_drug_dispensations.rb

echo -e "\n\nRunning patients with blank outcomes report..."
ruby comparatives/patients_with_blank_outcomes.rb
