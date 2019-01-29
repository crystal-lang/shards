require "./command"

module Shards
  module Commands
    class Update < Command
      # TODO: only update specified dependencies (ie. load locked versions, but don't enforce them)
      def run
        manager.resolve

        install(manager.packages)

        if generate_lockfile?
          manager.to_lock(lockfile_path)
        end
      end

      private def install(packages : Set)
        packages
          .compact_map { |package| install(package) }
          .each(&.postinstall)

        # always install executables because the path resolver never installs
        # dependencies, but uses them as-is:
        packages.each(&.install_executables)
      end

      private def install(package : Package)
        if package.installed?
          Shards.logger.info "Using #{package.name} (#{package.report_version})"
          return
        end

        Shards.logger.info "Installing #{package.name} (#{package.report_version})"
        package.install
        package
      end

      private def generate_lockfile?
        !Shards.production? && manager.packages.any?
      end
    end
  end
end
