require "../spec"
require "../manager"
require "./command"

module Shards
  module Commands
    class Install < Command
      getter :spec, :manager

      def initialize(path)
        @spec = Spec.from_file(path)
        @manager = Shards::Manager.new(spec)
      end

      def run
        manager.resolve
        manager.packages.each do |package|
          if package.installed?
            Shards.logger.info "Using #{package.name} (#{package.version})"
          else
            Shards.logger.info "Installing #{package.name} (#{package.version})"
            package.install
          end
        end
      end
    end

    def self.install(path = Dir.working_directory)
      Install.new(path).run
    end
  end
end
