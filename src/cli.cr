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
          lock [--update] [<shards>...]        - Lock dependencies in `shard.lock` but doesn't install them.
          outdated [--pre]                     - List dependencies that are outdated.
          prune                                - Remove unused dependencies from `lib` folder.
          update [<shards>...]                 - Update dependencies and `shard.lock`.
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
      opts.on("--frozen", "Strictly installs locked versions from shard.lock.") do
        self.frozen = true
      end
      opts.on("--without-development", "Does not install development dependencies.") do
        self.with_development = false
      end
      opts.on("--production", "same as `--frozen --without-development`") do
        self.frozen = true
        self.with_development = false
      end
      opts.on("--skip-postinstall", "Does not run postinstall of dependencies") do
        self.skip_postinstall = true
      end
      opts.on("--local", "Don't update remote repositories, use the local cache only.") { self.local = true }
      opts.on("--ignore-crystal-version", "Kept for compatibility, to be removed in the future.") {  }
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
            path
          )
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
          Commands::Outdated.run(
            path,
            prereleases: args.includes?("--pre")
          )
        when "prune"
          Commands::Prune.run(path)
        when "update"
          Commands::Update.run(
            path,
            args[1..-1].reject(&.starts_with?("--"))
          )
        when "version"
          Commands::Version.run(args[1]? || path)
        else
          program_name = "shards-#{args[0]}"
          if program_path = Process.find_executable(program_name)
            run_shards_subcommand(program_path, args)
          else
            display_help_and_exit(opts)
          end
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

  def self.run_shards_subcommand(process_name, args)
    Process.exec(
      command: process_name,
      args: args[1..],
    )
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
