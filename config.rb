# frozen_string_literal: true

require 'yaml'

def config
  @config ||= File.open('config.yaml') do |config_file|
    YAML.safe_load(config_file)
  end
end
