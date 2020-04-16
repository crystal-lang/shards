require "./command"

module Shards
  module Commands
    class List < Command
      @tree = false

      def run(@tree = false)
        return unless has_dependencies?
        puts "Shards installed:"
        list(spec.dependencies)
        list(spec.development_dependencies) unless Shards.production?
      end

      private def list(dependencies, level = 1)
        dependencies.each do |dependency|
          resolver = dependency.resolver

          # FIXME: duplicated from Check#verify
          unless _spec = resolver.installed_spec
            Log.debug { "#{dependency.name}: not installed" }
            raise Error.new("Dependencies aren't satisfied. Install them with 'shards install'")
          end

          indent = "  " * level
          puts "#{indent}* #{_spec.name} (#{resolver.report_version _spec.version})"

          indent_level = @tree ? level + 1 : level
          list(_spec.dependencies, indent_level)
        end
      end

      # FIXME: duplicates Check#has_dependencies?
      private def has_dependencies?
        spec.dependencies.any? || (!Shards.production? && spec.development_dependencies.any?)
      end
    end
  end
end
