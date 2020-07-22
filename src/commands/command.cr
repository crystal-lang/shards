require "../lock"
require "../spec"

module Shards
  abstract class Command
    getter path : String
    getter spec_path : String
    getter lockfile_path : String

    @spec : Spec?
    @locks : Lock?

    def initialize(path)
      if File.directory?(path)
        @path = path
        @spec_path = File.join(path, SPEC_FILENAME)
      else
        @path = File.dirname(path)
        @spec_path = path
      end
      @lockfile_path = File.join(@path, LOCK_FILENAME)
    end

    def self.run(path, *args, **kwargs)
      new(path).run(*args, **kwargs)
    end

    def spec
      @spec ||= if File.exists?(spec_path)
                  Spec.from_file(spec_path)
                else
                  raise Error.new("Missing #{spec_filename}. Please run 'shards init'")
                end
    end

    def spec_filename
      File.basename(spec_path)
    end

    def locks
      @locks ||= if lockfile?
                   Shards::Lock.from_file(lockfile_path)
                 else
                   raise Error.new("Missing #{LOCK_FILENAME}. Please run 'shards install'")
                 end
    end

    def lockfile?
      File.exists?(lockfile_path)
    end

    def write_lockfile(packages)
      Log.info { "Writing #{LOCK_FILENAME}" }
      Shards::Lock.write(packages, LOCK_FILENAME)
    end

    def handle_resolver_errors
      yield
    rescue e : Molinillo::ResolverError
      if e.is_a?(Molinillo::VersionConflict) && e.conflicts.has_key?(CrystalResolver.key)
        suggestion = ", try updating incompatible shards or use --ignore-crystal-version as a workaround if no update is available."
      end

      Log.error { e.message }
      raise Shards::Error.new("Failed to resolve dependencies#{suggestion}")
    end

    def check_ignored_crystal_version(packages)
      crystal_version = Shards::Version.new Shards.crystal_version

      warned = false
      packages.each do |package|
        crystal_req = MolinilloSolver.crystal_version_req(package.spec)

        if !Shards::Versions.matches?(crystal_version, crystal_req)
          warned = true
          Log.warn { "Shard \"#{package.name}\" may be incompatible with Crystal #{Shards.crystal_version}" }
        end
      end

      unless warned
        Log.warn { "Using --ignore-crystal-version was not needed. All shards are already compatible with Crystal #{Shards.crystal_version}" }
      end
    end
  end
end
