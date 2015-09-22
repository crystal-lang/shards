require "option_parser"
require "./commands/*"

module Shards
  def self.display_help_and_exit(opts)
    puts "shards [options] <command>"
    puts
    puts "Commands:"
    puts "    check"
    #puts "    info <package>"
    puts "    install"
    #puts "    search <query>"
    puts "    update"
    #puts "    update [package package ...]"
    puts
    puts "Options:"
    puts opts
    exit
  end
end

begin
  OptionParser.parse! do |opts|
    opts.on("--no-colors", "") { Shards.colors = false }
    opts.on("--version", "") { puts Shards.version_string; exit }
    opts.on("--production", "") { Shards.production = true }
    opts.on("-v", "--verbose", "") { Shards.logger.level = Logger::Severity::DEBUG }
    opts.on("-q", "--quiet", "") { Shards.logger.level = Logger::Severity::WARN }
    opts.on("-h", "--help", "") { Shards.display_help_and_exit(opts) }

    opts.unknown_args do |args, options|
      case args[0]? || Shards::DEFAULT_COMMAND
      when "check"
        Shards::Commands.check
      #when "info"
      #  Shards.display_help_and_exit(opts) unless args[1]?
      #  Shards::Commands.info(args[1])
      when "install"
        Shards::Commands.install
      when "update"
        Shards::Commands.update
        #Shards::Commands.update(*args[1 .. -1])
      #when "search"
      #  Shards.display_help_and_exit(opts) unless args[1]?
      #  Shards::Commands.search(args[1])
      else
        Shards.display_help_and_exit(opts)
      end
    end
  end

rescue ex : OptionParser::InvalidOption
  Shards.logger.fatal ex.message
  exit 1

rescue ex : Shards::ParseError
  ex.to_s(STDERR)
  exit 1

rescue ex : Shards::Error
  Shards.logger.error ex.message
  exit 1
end
