require "option_parser"
require "./commands/*"

module Shards
  def self.display_help(opts)
    puts <<-HELP
      shards [<options>...] [<command>]

      Commands:
          build [<targets>] [<options>]  - Build the specified <targets> in `bin` path.
          check                          - Verify all dependencies are installed.
          info [<options>...]            - Show information about a shard. Pass `--help` for details.
          init                           - Initialize a `shard.yml` file.
          install                        - Install dependencies, creating or using the `shard.lock` file.
          list [--tree]                  - List installed dependencies.
          lock [--update] [<shards>]     - Lock dependencies in `shard.lock` but doesn't install them.
          outdated [--pre]               - List dependencies that are outdated.
          prune                          - Remove unused dependencies from `lib` folder.
          update [<shards>]              - Update dependencies and `shard.lock`.
          version [<path>]               - Print the current version of the shard.
          --version                      - Print the `shards` version.
          -h, --help                     - Print usage synopsis.

      Options:
      HELP
    puts opts
  end

  def self.run
    OptionParser.parse(ARGV) do |opts|
      path = Dir.current

      opts.on("--no-color", "Disable colored output.") { self.colors = false }
      opts.on("--production", "Run in release mode. No development dependencies and strict sync between shard.yml and shard.lock.") { self.production = true }
      opts.on("--local", "Don't update remote repositories, use the local cache only.") { self.local = true }
      opts.on("-v", "--verbose", "Increase the log verbosity, printing all debug statements.") { self.set_debug_log_level }
      opts.on("-q", "--quiet", "Decrease the log verbosity, printing only warnings and errors.") { self.set_warning_log_level }

      opts.unknown_args do |args, options|
        case args.shift? || DEFAULT_COMMAND
        when "build"
          build(path, args)
        when "check"
          Commands::Check.run(path)
        when "info"
          Commands::Info.run(path, args)
        when "init"
          Commands::Init.run(path)
        when "install"
          Commands::Install.run(path)
        when "list"
          Commands::List.run(path, tree: args.includes?("--tree"))
        when "lock"
          Commands::Lock.run(
            path,
            args.reject(&.starts_with?("--")),
            print: args.includes?("--print"),
            update: args.includes?("--update")
          )
        when "outdated"
          Commands::Outdated.run(path, prereleases: args.includes?("--pre"))
        when "prune"
          Commands::Prune.run(path)
        when "update"
          Commands::Update.run(
            path,
            args.reject(&.starts_with?("--"))
          )
        when "version"
          Commands::Info.run(args.shift? || path, ["--version"])
        when "--version"
          puts self.version_string
        when "-h", "--help"
          display_help(opts)
        else
          display_help(opts)
          exit 1
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
  Shards::Log.fatal { ex.message }
  exit 1
rescue ex : Shards::ParseError
  ex.to_s(STDERR)
  exit 1
rescue ex : Shards::Error
  Shards::Log.error { ex.message }
  exit 1
end
