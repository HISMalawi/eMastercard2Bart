# frozen_string_literal: true

require_relative './config'
require_relative './logging'

require 'cgi'
require 'sequel'

def nart_db
  @nart_db ||= proc do
    db_config = config['emr']

    LOGGER.debug('Retrieving NART database instance')
    return @from_table if @from_table

    LOGGER.debug('Loading NART database configuration')
    engine = db_config['engine'] || 'mysql2'
    username = CGI.escape(db_config['username'])
    password = CGI.escape(db_config['password'])
    host = db_config['host'] || 'localhost'
    port = db_config['port'] || 3306
    database = db_config['database']

    LOGGER.debug('Connecting to NART database')
    db = Sequel.connect("#{engine}://#{username}:#{password}@#{host}:#{port}/#{database}")
    db.loggers << Logger.new(STDOUT)

    db
  end.call
end

def emastercard_db
  @emastercard_db ||= proc do
    LOGGER.debug('Loading eMastercard database configuration...')
    db_config = config['emastercard']

    engine = db_config['engine'] || 'mysql2'
    username = CGI.escape(db_config['username'])
    password = CGI.escape(db_config['password'])
    host = db_config['host'] || 'localhost'
    port = db_config['port'] || 3306
    database = db_config['database']

    LOGGER.debug('Connecting to eMastercard database...')
    db = Sequel.connect("#{engine}://#{username}:#{password}@#{host}:#{port}/#{database}")
    db.loggers << Logger.new(STDOUT)

    db
  end.call
end
