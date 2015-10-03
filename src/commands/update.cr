require "./command"

module Shards
  module Commands
    class Update < Command
      # TODO: only update specified dependencies (ie. load locked versions, but don't enforce them)
      def run
        manager.resolve

        manager.packages.each do |package|
          if package.installed?(loose: false)
            Shards.logger.info "Using #{package.name} (#{package.version})"
          else
            Shards.logger.info "Installing #{package.name} (#{package.version})"
            package.install
          end
        end

        manager.to_lock(lockfile_path)
      end
    end
  end
end
