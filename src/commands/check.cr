require "../spec"
require "../manager"
require "./command"

module Shards
  module Commands
    class Check < Command
      getter :spec, :manager

      def initialize(path)
        @spec = Spec.from_file(path)
        @manager = Shards::Manager.new(spec, update_cache: false)
      end

      def run
        manager.resolve

        manager.packages.each do |package|
          unless package.installed?(loose: true)
            raise Error.new("Missing #{package.name} (#{package.version})")
          end
        end
      end
    end

    def self.check(path = Dir.working_directory)
      Check.new(path).run
    end
  end
end
