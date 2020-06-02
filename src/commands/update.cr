require "./command"
require "../molinillo_solver"

module Shards
  module Commands
    class Update < Command
      def run(shards : Array(String))
        Log.info { "Resolving dependencies" }

        solver = MolinilloSolver.new(spec)

        if lockfile? && !shards.empty?
          # update selected dependencies to latest possible versions, but
          # avoid to update unspecified dependencies, if possible:
          solver.locks = locks.shards.reject { |d| shards.includes?(d.name) }
        end

        solver.prepare(development: !Shards.production?)

        packages = handle_resolver_errors { solver.solve }
        install(packages)

        if generate_lockfile?(packages)
          write_lockfile(packages)
        end
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
        !(Shards.production? || packages.empty?)
      end
    end
  end
end
