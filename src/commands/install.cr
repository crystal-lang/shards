require "./command"
require "../solver"

module Shards
  module Commands
    class Install < Command
      def run
        Shards.logger.info { "Resolving dependencies" }

        solver = Solver.new(spec)

        if lockfile?
          # install must be as conservative as possible:
          solver.locks = locks
        end

        solver.prepare(development: !Shards.production?)

        if packages = solver.solve
          install(packages)

          if generate_lockfile?(packages)
            write_lockfile(packages)
          end
        else
          solver.each_conflict do |message|
            Shards.logger.warn { "Conflict #{message}" }
          end
          Shards.logger.error { "Failed to resolve dependencies" }
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
          Shards.logger.info { "Using #{package.name} (#{package.report_version})" }
          return
        end

        Shards.logger.info { "Installing #{package.name} (#{package.report_version})" }
        package.install
        package
      end

      private def generate_lockfile?(packages)
        !Shards.production? && !packages.empty? && (!lockfile? || outdated_lockfile?(packages))
      end

      private def outdated_lockfile?(packages)
        a = packages.map { |x| {x.name, x.version, x.commit} }
        b = locks.map { |x| {x.name, x["version"], x["commit"]?} }
        a != b
      end
    end
  end
end
