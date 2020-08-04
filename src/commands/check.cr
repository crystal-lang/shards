require "./command"
require "../versions"

module Shards
  module Commands
    class Check < Command
      def run
        if has_dependencies?
          locks # ensures that lockfile exists
          verify(spec.dependencies)
          verify(spec.development_dependencies) unless Shards.production?
        end

        Log.info { "Dependencies are satisfied" }
      end

      private def has_dependencies?
        spec.dependencies.any? || (!Shards.production? && spec.development_dependencies.any?)
      end

      private def verify(dependencies)
        dependencies.each do |dependency|
          Log.debug { "#{dependency.name}: checking..." }

          unless installed?(dependency)
            raise Error.new("Dependencies aren't satisfied. Install them with 'shards install'")
          end
        end
      end

      private def installed?(dependency)
        unless lock = locks.shards.find { |d| d.name == dependency.name }
          Log.debug { "#{dependency.name}: not locked" }
          return false
        end

        if version = lock.requirement.as?(Shards::Version)
          if !dependency.matches?(version)
            Log.debug { "#{dependency.name}: lock conflict" }
            return false
          else
            package = Package.new(lock.name, lock.resolver, version)
            return false unless package.installed?
            verify(package.spec.dependencies)
            return true
          end
        else
          raise Error.new("Invalid #{LOCK_FILENAME}. Please run `shards install` to fix it.")
        end
      end
    end
  end
end
