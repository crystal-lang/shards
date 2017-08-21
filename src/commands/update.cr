require "./command"

module Shards
  module Commands
    class Update < Command
      # TODO: only update specified dependencies (ie. load locked versions, but don't enforce them)
      def run(*args)
        manager.resolve

        manager.packages.each do |package|
          if package.installed?
            Shards.logger.info "Using #{package.name} (#{package.report_version})"
          else
            Shards.logger.info "Installing #{package.name} (#{package.report_version})"
            package.install
          end
        end

        if generate_lockfile?
          manager.to_lock(lockfile_path)
        end
      end

      private def generate_lockfile?
        !Shards.production? && manager.packages.any?
      end
    end
  end
end
