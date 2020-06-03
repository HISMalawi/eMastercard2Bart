# frozen_string_literal: true

require 'parallel'
require 'securerandom'

require_relative '../databases'
require_relative '../config'
require_relative '../nart_db' # Required by loader module
require_relative '../nart_constants'
require_relative '../loaders/patient'

CONFIG = config
EMR_USER_ID = config['emr_user_id']
EMR_LOCATION_ID = config['emr_location_id']

def main
  Parallel.each(dispensations_without_orders, in_threads: 8) do |dispensation|
    order = find_dispensation_order(dispensation[:person_id], dispensation[:obs_datetime], dispensation[:value_drug])
    next unless order

    nart_db[:obs].where(obs_id: dispensation[:obs_id])
                 .update(order_id: order[:order_id])
  end
end

def dispensations_without_orders
  nart_db[:obs].where(concept_id: Nart::Concepts::AMOUNT_DISPENSED, order_id: nil)
               .select(:obs_id, :person_id, :obs_datetime, :value_drug)
               .all
end

def find_dispensation_order(person_id, date, drug_id)
  nart_db[:orders].join(:drug_order, order_id: :order_id)
                  .where(Sequel[:drug_order][:drug_inventory_id] => drug_id,
                         start_date: date.strftime('%Y-%m-%d 00:00:00')..date.strftime('%Y-%m-%d 23:59:59'),
                         patient_id: person_id)
                  .first
end

main
