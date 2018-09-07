require "option_parser"
require "./commands/*"

module Shards
  def self.display_help_and_exit(opts)
    puts <<-HELP
      shards [<options>...] [<command>]

      Commands:
          build [<targets>] [<options>]  - Builds the specified <targets> in `bin` path.
          check                          - Verifies all dependencies are installed.
          init                           - Initializes a shard folder.
          install                        - Installs dependencies from `shard.lock` file.
          list                           - Lists installed dependencies.
          prune                          - Removes unused dependencies from `lib` folder.
          update                         - Updates dependencies and `shards.lock`.
          version [<path>]               - Prints the current version of the shard.

      Options:
      HELP
    puts opts
    #    info <package>
    #    search <query>
    #     update [package package ...]
    exit
  end

  def self.run
    OptionParser.parse! do |opts|
      path = Dir.current

      opts.on("--no-color", "Disable colored output.") { self.colors = false }
      opts.on("--version", "Prints the `shards` version.") { puts self.version_string; exit }
      opts.on("--production", "Run in release mode. No development dependencies and strict sync between shard.yml and shard.lock.") { self.production = true }
      opts.on("-v", "--verbose", "Increases the log verbosity, printing all debug statements.") { self.logger.level = Logger::Severity::DEBUG }
      opts.on("-q", "--quiet", "Decreases the log verbosity, printing only warnings and errors.") { self.logger.level = Logger::Severity::WARN }
      opts.on("-h", "--help", "Prints usage synopsis.") { self.display_help_and_exit(opts) }

      opts.unknown_args do |args, _options|
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
