require "../spec"
require "../manager"
require "./command"

module Shards
  module Commands
    class Update < Command
      getter :spec, :manager

      def initialize(path)
        @spec = Spec.from_file(path)
        @manager = Shards::Manager.new(spec)
      end

      # TODO: force manager to resolver dependencies (again)
      # TODO: save shards.lock with new resolved dependencies
      # TODO: only update specified dependencies
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
      end
    end

    def self.update(path = Dir.working_directory)
      Update.new(path).run
    end
  end
end
