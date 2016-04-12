#require "logger"
require "colorize"

# Custom Logger class until https://github.com/manastech/crystal/issues/1781 is fixed
# :nodoc:
class Logger(T)
  property :level, :progname, :formatter

  enum Severity
    DEBUG
    INFO
    WARN
    ERROR
    FATAL
    UNKNOWN
  end

  alias Formatter = String, Time, String, String, String::Builder -> String::Builder

  # :nodoc:
  DEFAULT_FORMATTER = Formatter.new do |severity, datetime, progname, message, io|
    io << severity[0] << ", [" << datetime << " #" << Process.pid << "] "
    io << severity.rjust(5) << " -- " << progname << ": " << message
  end

  def initialize(@io : T)
    @level = Severity::INFO
    @formatter = DEFAULT_FORMATTER
    @progname = ""
  end

  def close
    @io.close
  end

  {% for name in Severity.constants %}
    {{name.id}} = Severity::{{name.id}}

    def {{name.id.downcase}}?
      level <= Severity::{{name.id}}
    end

    def {{name.id.downcase}}(message, progname = nil)
      log(Severity::{{name.id}}, message, progname)
    end

    def {{name.id.downcase}}(progname = nil)
      log(Severity::{{name.id}}, progname) { yield }
    end
  {% end %}

  def log(severity, progname = nil)
    log(severity, yield, progname)
  end

  def log(severity, message, progname = nil)
    return if severity < level

    @io << String.build do |str|
      label = severity == Severity::UNKNOWN ? "ANY" : severity.to_s
      formatter.call(label, Time.now, progname || @progname, message.to_s, str) << "\n"
    end

    @io.flush
  end
end

module Shards
  LOGGER_COLORS = {
    "ERROR" => :red,
    "WARN"  => :orange,
    "INFO"  => :light_green,
    "DEBUG" => :light_gray,
  }

  @@colors = true

  def self.colors=(value)
    @@colors = value
  end

  @@logger : Logger(IO::FileDescriptor)?

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
          io << severity[0] << ": " << message
        end
      end
    end
  end
end
