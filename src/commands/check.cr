require "../spec"
require "../manager"
require "../helpers/versions"
require "./command"

module Shards
  module Commands
    class Check < Command
      include Helpers::Versions

      getter :spec, :manager

      def initialize(@path)
        @spec = Spec.from_file(@path)
      end

      def run
        if has_dependencies?
          locks # ensures that lockfile exists
          verify(spec.dependencies)
          verify(spec.development_dependencies) unless Shards.production?
        end

        Shards.logger.info "Dependencies are satisfied"
      end

      private def has_dependencies?
        spec.dependencies.any? || !Shards.production? || spec.development_dependencies.any?
      end

      private def verify(dependencies)
        dependencies.each do |dependency|
          Shards.logger.debug { "#{ dependency.name }: checking..." }
          resolver = Shards.find_resolver(dependency)

          unless _spec = resolver.installed_spec
            Shards.logger.debug { "#{ dependency.name }: not installed" }
            raise Error.new("Dependencies aren't satisfied. Install them with 'shards install'")
          end

          unless installed?(dependency, _spec)
            raise Error.new("Dependencies aren't satisfied. Install them with 'shards install'")
          end

          verify(_spec.dependencies)
        end
      end

      private def installed?(dependency, spec)
        unless lock = locks.find { |d| d.name == spec.name }
          Shards.logger.debug { "#{ dependency.name }: not locked" }
          return false
        end

        if version = lock["version"]?
          if resolve_requirement([version], dependency.version).empty?
            Shards.logger.debug { "#{ dependency.name }: lock conflict" }
            return false
          else
            return spec.version == version
          end
        end

        #if commit = lock["commit"]?
        #  if resolver.responds_to?(:installed_commit)
        #    return resolver.installed_commit == commit
        #  else
        #    return false
        #  end
        #end

        if resolve_requirement([spec.version], dependency.version).empty?
          Shards.logger.debug { "#{ dependency.name }: version mismatch" }
          return false
        end

        true
      end

      private def locks
        @locks ||= begin
                     lock_path = if File.directory?(@path)
                                   File.expand_path(LOCK_FILENAME, @path)
                                 else
                                   File.expand_path(File.join("..", LOCK_FILENAME), @path)
                                 end

                     unless File.exists?(lock_path)
                       raise Error.new("Missing #{ LOCK_FILENAME }. Please run 'shards install'")
                     end

                     Lock.from_file(lock_path)
                   end
      end
    end

    def self.check(path = Dir.working_directory)
      Check.new(path).run
    end
  end
end
