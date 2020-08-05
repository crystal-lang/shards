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
        apply_overrides(dependencies).each do |dependency|
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

        if dependency.resolver != lock.resolver
          Log.debug { "#{dependency.name}: source changed" }
          return false
        elsif !dependency.matches?(lock.version)
          Log.debug { "#{dependency.name}: lock conflict" }
          return false
        else
          return false unless lock.installed?
          verify(lock.spec.dependencies)
          return true
        end
      end

      # FIXME: duplicates MolinilloSolver#on_override
      def on_override(dependency : Dependency) : Dependency?
        override.try(&.dependencies.find { |o| o.name == dependency.name })
      end

      # FIXME: duplicates MolinilloSolver#apply_overrides
      def apply_overrides(deps : Array(Dependency))
        deps.map { |dep| on_override(dep) || dep }
      end
    end
  end
end
