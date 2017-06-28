require "logger"
require "colorize"

module Shards
  LOGGER_COLORS = {
    "ERROR" => :red,
    "WARN"  => :light_yellow,
    "INFO"  => :light_green,
    "DEBUG" => :light_gray,
  }

  @@colors = true

  def self.colors=(value)
    @@colors = value
  end

  @@logger : Logger?

  def self.logger
    @@logger ||= Logger.new(STDOUT).tap do |logger|
      logger.progname = "shards"
      logger.level = Logger::Severity::INFO

      logger.formatter = Logger::Formatter.new do |severity, _datetime, _progname, message, io|
        if @@colors
          io << if color = LOGGER_COLORS[severity.to_s]?
                  if idx = message.index(" ")
                    message[0 ... idx].colorize(color).to_s + message[idx .. -1]
                  else
                    message.colorize(color)
                  end
                else
                  message
                end
        else
          io << severity.to_s[0] << ": " << message
        end
      end
    end
  end
end
