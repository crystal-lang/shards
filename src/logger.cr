require "colorize"

module Shards
  @@colors = true

  def self.colors=(value)
    @@colors = value
  end
end

{% if compare_versions(Crystal::VERSION, "0.34.0-0") > 0 %}
  require "log"

  Log.setup_from_env(
    level: ENV.fetch("CRYSTAL_LOG_LEVEL", "INFO"),
    sources: ENV.fetch("CRYSTAL_LOG_SOURCES", "shards.*"),
    backend: Log::IOBackend.new.tap do |backend|
      backend.formatter = Shards::FORMATTER
    end
  )

  module Shards
    Log = ::Log.for(self)

    def self.set_warning_log_level
      Log.level = ::Log::Severity::Warning
    end

    def self.set_debug_log_level
      Log.level = ::Log::Severity::Debug
    end

    LOGGER_COLORS = {
      ::Log::Severity::Error   => :red,
      ::Log::Severity::Warning => :yellow,
      ::Log::Severity::Info    => :green,
      ::Log::Severity::Debug   => :light_gray,
    }

    FORMATTER = ::Log::Formatter.new do |entry, io|
      message = entry.message

      if @@colors
        io << if color = LOGGER_COLORS[entry.severity]?
          if idx = message.index(' ')
            message[0...idx].colorize(color).to_s + message[idx..-1]
          else
            message.colorize(color)
          end
        else
          message
        end
      else
        io << entry.severity.label[0] << ": " << message
      end
    end
  end
{% else %}
  require "logger"

  module Shards
    LOGGER_COLORS = {
      "ERROR" => :red,
      "WARN"  => :yellow,
      "INFO"  => :green,
      "DEBUG" => :light_gray,
    }

    @@logger : Logger?

    def self.logger
      @@logger ||= Logger.new(STDOUT).tap do |logger|
        logger.progname = "shards"
        logger.level = Logger::Severity::INFO

        logger.formatter = Logger::Formatter.new do |severity, _datetime, _progname, message, io|
          if @@colors
            io << if color = LOGGER_COLORS[severity.to_s]?
              if idx = message.index(' ')
                message[0...idx].colorize(color).to_s + message[idx..-1]
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

    def self.set_warning_log_level
      logger.level = Logger::Severity::WARN
    end

    def self.set_debug_log_level
      logger.level = Logger::Severity::DEBUG
    end

    module Log
      {% for severity in %w(debug info warn error fatal) %}
        def self.{{severity.id}}
          Shards.logger.{{severity.id}} do
            yield
          end
        end
      {% end %}
    end
  end
{% end %}
