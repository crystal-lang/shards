require "../spec"
require "../manager"
require "./command"

module Shards
  module Commands
    class Update < Command
      getter :manager, :path

      def initialize(@path)
        spec = Spec.from_file(path)
        @manager = Manager.new(spec)
      end

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

        File.open(lock_file_path, "w") { |file| manager.to_lock(file) }
      end

      private def lock_file_path
        File.join(path, LOCK_FILENAME)
      end
    end

    def self.update(path = Dir.working_directory)
      Update.new(path).run
    end
  end
end
