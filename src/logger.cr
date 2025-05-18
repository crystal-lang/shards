require "colorize"
require "log"

module Shards
  class_property? colors : Bool = Colorize.on_tty_only!
end

Log.setup_from_env(
  default_sources: "shards.*",
  backend: Log::IOBackend.new(formatter: Shards::FORMATTER)
)

module Shards
  Log = ::Log.for(self)

  def self.set_warning_log_level
    Log.level = ::Log::Severity::Warn
  end

  def self.set_debug_log_level
    Log.level = ::Log::Severity::Debug
  end

  LOGGER_COLORS = {
    ::Log::Severity::Error => :red,
    ::Log::Severity::Warn  => :yellow,
    ::Log::Severity::Info  => :green,
    ::Log::Severity::Debug => :light_gray,
  }

  FORMATTER = ::Log::Formatter.new do |entry, io|
    message = entry.message
    package_name = entry.context[:package]?
    if @@colors
      io << "[" << package_name.colorize(:blue).to_s << "] " if package_name && entry.severity <= ::Log::Severity::Debug
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
      io << entry.severity.label[0] << ": "
      io << "[" << package_name << "] " if package_name && entry.severity <= ::Log::Severity::Debug
      io << message
    end
  end
end
