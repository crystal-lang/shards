require "logger"

module Shards
  def self.logger
    @@logger ||= Logger.new(STDOUT).tap do |logger|
      logger.progname = "shards"
      logger.level = Logger::Severity::DEBUG

      logger.formatter = Logger::Formatter.new do |severity, _datetime, _progname, message, io|
        io << severity[0] << ": " << message
      end
    end
  end
end
