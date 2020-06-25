require "option_parser"
require "./commands/*"

module Shards
  def self.display_help_and_exit(opts)
    puts <<-HELP
      shards [<options>...] [<command>]

      Commands:
          build [<targets>] [<build_options>]  - Build the specified <targets> in `bin` path, all build_options are delegated to `crystal build`.
          check                                - Verify all dependencies are installed.
          init                                 - Initialize a `shard.yml` file.
          install                              - Install dependencies, creating or using the `shard.lock` file.
          list [--tree]                        - List installed dependencies.
          lock [--update] [<shards>]           - Lock dependencies in `shard.lock` but doesn't install them.
          outdated [--pre]                     - List dependencies that are outdated.
          prune                                - Remove unused dependencies from `lib` folder.
          update [<shards>]                    - Update dependencies and `shard.lock`.
          version [<path>]                     - Print the current version of the shard.

      General options:
      HELP
    puts opts
    exit
  end

  def self.run
    OptionParser.parse(cli_options) do |opts|
      path = Dir.current

      opts.on("--no-color", "Disable colored output.") { self.colors = false }
      opts.on("--version", "Print the `shards` version.") { puts self.version_string; exit }
      opts.on("--production", "Run in release mode. No development dependencies and strict sync between shard.yml and shard.lock.") { self.production = true }
      opts.on("--local", "Don't update remote repositories, use the local cache only.") { self.local = true }
      opts.on("-v", "--verbose", "Increase the log verbosity, printing all debug statements.") { self.set_debug_log_level }
      opts.on("-q", "--quiet", "Decrease the log verbosity, printing only warnings and errors.") { self.set_warning_log_level }
      opts.on("-h", "--help", "Print usage synopsis.") { self.display_help_and_exit(opts) }

      opts.unknown_args do |args, options|
        case args[0]? || DEFAULT_COMMAND
        when "build"
          build(path, args[1..-1])
        when "check"
          Commands::Check.run(path)
        when "init"
          Commands::Init.run(path)
        when "install"
          Commands::Install.run(
            path,
            ignore_crystal_version: args.includes?("--ignore-crystal-version")
          )
        when "list"
          Commands::List.run(path, tree: args.includes?("--tree"))
        when "lock"
          Commands::Lock.run(
            path,
            args[1..-1].reject(&.starts_with?("--")),
            print: args.includes?("--print"),
            update: args.includes?("--update"),
            ignore_crystal_version: args.includes?("--ignore-crystal-version")
          )
        when "outdated"
          Commands::Outdated.run(
            path,
            prereleases: args.includes?("--pre"),
            ignore_crystal_version: args.includes?("--ignore-crystal-version")
          )
        when "prune"
          Commands::Prune.run(path)
        when "update"
          Commands::Update.run(
            path,
            args[1..-1].reject(&.starts_with?("--")),
            ignore_crystal_version: args.includes?("--ignore-crystal-version")
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

  def self.cli_options
    shards_opts : Array(String)
    {% if compare_versions(Crystal::VERSION, "1.0.0-0") > 0 %}
      shards_opts = Process.parse_arguments(ENV.fetch("SHARDS_OPTS", ""))
    {% else %}
      shards_opts = ENV.fetch("SHARDS_OPTS", "").split
    {% end %}
    ARGV.concat(shards_opts)
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
