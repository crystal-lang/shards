require "./command"
require "../molinillo_solver"

module Shards
  module Commands
    class Install < Command
      def run
        Log.info { "Resolving dependencies" }

        solver = MolinilloSolver.new(spec)

        if lockfile?
          # install must be as conservative as possible:
          solver.locks = locks
        end

        solver.prepare(development: !Shards.production?)

        packages = handle_resolver_errors { solver.solve }
        return if packages.empty?

        if lockfile? && Shards.production?
          validate(packages)
        end

        install(packages)

        if generate_lockfile?(packages)
          write_lockfile(packages)
        end
      end

      private def validate(packages)
        packages.each do |package|
          if lock = locks.find { |d| d.name == package.name }
            if commit = lock["commit"]?
              validate_locked_commit(package, commit)
            elsif version = lock.version?
              validate_locked_version(package, version)
            else
              raise InvalidLock.new # unknown lock resolver
            end
          else
            raise LockConflict.new("can't install new dependency #{package.name} in production")
          end
        end
      end

      private def validate_locked_version(package, version)
        return if package.version == version
        raise LockConflict.new("#{package.name} requirements changed")
      end

      private def validate_locked_commit(package, commit)
        return if package.commit == commit
        raise LockConflict.new("#{package.name} requirements changed")
      end

      private def install(packages : Array(Package))
        # first install all dependencies:
        installed = packages.compact_map { |package| install(package) }

        # then execute the postinstall script of installed dependencies (with
        # access to all transitive dependencies):
        installed.each(&.postinstall)

        # always install executables because the path resolver never actually
        # installs dependencies:
        packages.each(&.install_executables)
      end

      private def install(package : Package)
        if package.installed?
          Log.info { "Using #{package.name} (#{package.report_version})" }
          return
        end

        Log.info { "Installing #{package.name} (#{package.report_version})" }
        package.install
        package
      end

      private def generate_lockfile?(packages)
        !Shards.production? && !packages.empty? && (!lockfile? || outdated_lockfile?(packages))
      end

      private def outdated_lockfile?(packages)
        a = packages.map { |x| {x.name, x.version, x.commit} }
        b = locks.map { |x| {x.name, x["version"]?, x["commit"]?} }
        a != b
      end
    end
  end
end
