require "option_parser"
require "./commands/*"

module Shards
  def self.display_help_and_exit(opts)
    puts <<-HELP
      shards [<options>...] [<command>]

      Commands:
          build [<targets>] [<options>]  - Build the specified <targets> in `bin` path.
          check                          - Verify all dependencies are installed.
          init                           - Initialize a `shard.yml` file.
          install                        - Install dependencies, creating or using the `shard.lock` file.
          list [--tree]                  - List installed dependencies.
          lock [--update] [<shards>]     - Lock dependencies in `shard.lock` but doesn't install them.
          outdated [--pre]               - List dependencies that are outdated.
          prune                          - Remove unused dependencies from `lib` folder.
          run [<target>] [<options>]     - Build and run specific target
          update [<shards>]              - Update dependencies and `shard.lock`.
          version [<path>]               - Print the current version of the shard.

      Options:
      HELP
    puts opts
    exit
  end

  def self.run
    OptionParser.parse(ARGV) do |opts|
      path = Dir.current

      opts.on("--no-color", "Disable colored output.") { self.colors = false }
      opts.on("--version", "Print the `shards` version.") { puts self.version_string; exit }
      opts.on("--production", "Run in release mode. No development dependencies and strict sync between shard.yml and shard.lock.") { self.production = true }
      opts.on("--local", "Don't update remote repositories, use the local cache only.") { self.local = true }
      opts.on("-v", "--verbose", "Increase the log verbosity, printing all debug statements.") { self.logger.level = Logger::Severity::DEBUG }
      opts.on("-q", "--quiet", "Decrease the log verbosity, printing only warnings and errors.") { self.logger.level = Logger::Severity::WARN }
      opts.on("-h", "--help", "Print usage synopsis.") { self.display_help_and_exit(opts) }

      opts.unknown_args do |args, options|
        case args[0]? || DEFAULT_COMMAND
        when "build"
          targets, command_options = parse_args(args[1..-1])
          check_and_install_dependencies(path)
          Commands::Build.run(path, targets, command_options)
        when "check"
          Commands::Check.run(path)
        when "init"
          Commands::Init.run(path)
        when "install"
          Commands::Install.run(path)
        when "list"
          Commands::List.run(path, tree: args.includes?("--tree"))
        when "lock"
          Commands::Lock.run(
            path,
            args[1..-1].reject(&.starts_with?("--")),
            print: args.includes?("--print"),
            update: args.includes?("--update")
          )
        when "outdated"
          Commands::Outdated.run(path, prereleases: args.includes?("--pre"))
        when "prune"
          Commands::Prune.run(path)
        when "run"
          targets, command_options = parse_args(args[1..-1])
          check_and_install_dependencies(path)
          Commands::Run.run(path, targets, command_options, options)
        when "update"
          Commands::Update.run(
            path,
            args[1..-1].reject(&.starts_with?("--"))
          )
        when "version"
          Commands::Version.run(args[1]? || path)
        else
          display_help_and_exit(opts)
        end

        exit
      end
    end
  end

  def self.parse_args(args)
    targets = [] of String
    options = [] of String

    args.each do |arg|
      if arg.starts_with?('-')
        options << arg
      else
        targets << arg
      end
    end
    { targets, options }
  end

  def self.check_and_install_dependencies(path)
    Commands::Check.run(path)
  rescue
    Commands::Install.run(path)
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
