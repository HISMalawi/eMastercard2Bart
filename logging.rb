# frozen_string_literal: true

require 'logger'

LOGGER = Logger.new(STDOUT)

DEBUG_LEVEL = ['0', 'false'].include?(ENV['debug']&.downcase&.trim) ? Logger::WARN : Logger::DEBUG
LOGGER.level = DEBUG_LEVEL