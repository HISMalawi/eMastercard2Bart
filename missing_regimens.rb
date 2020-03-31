#!/usr/bin/env ruby

require 'yaml'

errors = File.open('errors.yaml') do |fin|
  3.times { fin.readline } # First 3 lines are summary of the migration results
  YAML.safe_load(fin)
end

patients_with_regimen_errors = []

def extract_visit_dates(errors)
  errors.map do |error|
    match = error.match(/(\d{4}-\d{2}-\d{2})/)
    next nil unless match

    match[1]
  end.reject(&:nil?)
end

errors.each do |field, value|
  next unless value.respond_to?(:each)

  last_visit_date = extract_visit_dates(value).select do |date|
    date >= '2019-10-01 00:00:00' && date <= '2019-12-31 23:59:59'
  end.max

  value.each do |error|
    next unless last_visit_date && error.match?(/.*regimen.*/i) && error.include?(last_visit_date)

    patients_with_regimen_errors << "#{field} - #{error}\n"
  end
end

print "Total patients with regimen errors: #{patients_with_regimen_errors.size}\n"
patients_with_regimen_errors.each do |patient|
  puts patient
end

