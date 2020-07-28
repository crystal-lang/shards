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
          installed = Shards.info.installed[dependency.name]
          unless installed
            Log.debug { "#{dependency.name}: not installed" }
            raise Error.new("Dependencies aren't satisfied. Install them with 'shards install'")
          end

          version = installed.requirement.as(Shards::Version)
          package = Package.new(installed.name, installed.resolver, version)
          resolver = installed.resolver

          indent = "  " * level
          puts "#{indent}* #{dependency.name} (#{resolver.report_version version})"

          indent_level = @tree ? level + 1 : level
          list(package.spec.dependencies, indent_level)
        end
      end

      # FIXME: duplicates Check#has_dependencies?
      private def has_dependencies?
        spec.dependencies.any? || (!Shards.production? && spec.development_dependencies.any?)
      end
    end
  end
end
