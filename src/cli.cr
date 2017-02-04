require "option_parser"
require "./commands/*"

module Shards
  def self.display_help_and_exit(opts)
    puts "shards [options] <command>"
    puts
    puts "Commands:"
    puts "    build [targets] [options]"
    puts "    check"
    #puts "    info <package>"
    puts "    init"
    puts "    install"
    puts "    list"
    puts "    prune"
    #puts "    search <query>"
    puts "    update"
    # puts "    update [package package ...]"
    puts "    version [path]"
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
        when "build"
          build(path, args[1..-1])
        when "check"
          Commands::Check.run(path)
        #when "info"
        #  display_help_and_exit(opts) unless args[1]?
        #  Commands::Info.run(args[1])
        when "init"
          Commands::Init.run(path)
        when "install"
          Commands::Install.run(path)
        when "list"
          Commands::List.run(path)
        when "prune"
          Commands::Prune.run(path)
          # when "search"
          #  display_help_and_exit(opts) unless args[1]?
          #  Commands::Search.run(path, args[1])
        when "update"
          Commands::Update.run(path)
          # Commands.update(path, *args[1..-1])
        when "version"
          Commands::Version.run(args[1]? || path)
        else
          display_help_and_exit(opts)
        end

        exit
      end
    end
  end

  def self.build(path, args)
    targets = [] of String
    options = [] of String

    args.each do |arg|
      if arg.starts_with?('-')
        options << arg
      else
        targets << arg
      end
    end

    begin
      Commands::Check.run(path)
    rescue
      Commands::Install.run(path)
    end

    Commands::Build.run(path, targets, options)
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
