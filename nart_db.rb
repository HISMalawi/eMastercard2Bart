# frozen_string_literal: true

module NartDb
  def self.from_table
    LOGGER.debug('Retrieving NART database instance')
    return @from_table if @from_table

    LOGGER.debug('Loading NART database configuration')
    config = CONFIG['emr']
    engine = config['engine'] || 'mysql2'
    username = config['username']
    password = config['password']
    host = config['host'] || 'localhost'
    port = config['port'] || 3306
    database = config['database']

    LOGGER.debug('Connecting to NART database')
    @from_table = Sequel.connect("#{engine}://#{username}:#{password}@#{host}:#{port}/#{database}")
    @from_table.loggers << Logger.new(STDOUT)
    @from_table
  end

  class << self
    alias into_table from_table
  end
end
