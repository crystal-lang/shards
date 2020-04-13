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
          resolver = Shards.find_resolver(dependency)

          unless _spec = resolver.installed_spec
            Log.debug { "#{dependency.name}: not installed" }
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
          Log.debug { "#{dependency.name}: not locked" }
          return false
        end

        if version = lock["version"]?
          if Versions.resolve([version], dependency.version).empty?
            Log.debug { "#{dependency.name}: lock conflict" }
            return false
          else
            return spec.version == version
          end
        end

        # if commit = lock["commit"]?
        #  if resolver.responds_to?(:installed_commit)
        #    return resolver.installed_commit == commit
        #  else
        #    return false
        #  end
        # end

        if Versions.resolve([spec.version], dependency.version).empty?
          Log.debug { "#{dependency.name}: version mismatch" }
          return false
        end

        true
      end
    end
  end
end
