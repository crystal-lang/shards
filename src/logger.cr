require "colorize"
require "log"

module Shards
  @@colors = true

  def self.colors=(value)
    @@colors = value
  end
end

{% if compare_versions(Crystal::VERSION, "0.35.0-0") > 0 %}
  Log.setup_from_env(
    default_sources: "shards.*",
    backend: Log::IOBackend.new(formatter: Shards::FORMATTER)
  )
{% else %}
  Log.setup_from_env(
    level: ENV.fetch("LOG_LEVEL", "INFO"),
    sources: "shards.*",
    backend: Log::IOBackend.new.tap do |backend|
      backend.formatter = Shards::FORMATTER
    end
  )
{% end %}

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
