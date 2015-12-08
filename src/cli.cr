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
    puts "    list"
    #puts "    search <query>"
    puts "    update"
    #puts "    update [package package ...]"
    puts
    puts "Options:"
    puts opts
    exit
  end

  def self.run
    OptionParser.parse! do |opts|
      path = Dir.current

      opts.on("--no-color", "") { self.colors = false }
      opts.on("--version", "") { puts self.version_string; exit }
      opts.on("--production", "") { self.production = true }
      opts.on("-v", "--verbose", "") { self.logger.level = Logger::Severity::DEBUG }
      opts.on("-q", "--quiet", "") { self.logger.level = Logger::Severity::WARN }
      opts.on("-h", "--help", "") { self.display_help_and_exit(opts) }

      opts.unknown_args do |args, options|
        case args[0]? || DEFAULT_COMMAND
        when "check"
          Commands::Check.run(path)
        #when "info"
        #  display_help_and_exit(opts) unless args[1]?
        #  Commands::Info.run(args[1])
        when "install"
          Commands::Install.run(path)
        when "list"
          Commands::List.run(path)
        #when "search"
        #  display_help_and_exit(opts) unless args[1]?
        #  Commands::Search.run(args[1])
        when "update"
          Commands::Update.run(path)
          #Commands.update(*args[1 .. -1])
        else
          display_help_and_exit(opts)
        end
      end
    end
  end
end

begin
  Shards.run

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
