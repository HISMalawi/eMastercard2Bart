# frozen_string_literal: true

module NartDbUtils
  def sequel
    return @sequel if @sequel

    config = File.open("#{__dir__}/config.yaml") do |config_file|
      YAML.safe_load(config_file)['emr']
    end

    engine = config['engine'] || 'mysql2'
    username = config['username']
    password = config['password']
    host = config['host'] || 'localhost'
    port = config['port'] || 3306
    database = config['database']

    @sequel = Sequel.connect("#{engine}://#{username}:#{password}@#{host}:#{port}/#{database}")
    @sequel.loggers << Logger.new(STDOUT)
    @sequel
  end
end
