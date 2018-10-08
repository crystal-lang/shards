require "../helpers/versions"
require "./command"

module Shards
  module Commands
    class List < Command
      property tree_mode = false

      def run(args = [] of String)
        return unless has_dependencies?
        self.tree_mode = args.first? == "--tree"

        puts "Shards installed:"
        list(spec.dependencies)
        list(spec.development_dependencies) unless Shards.production?
      end

      private def list(dependencies, level = 1)
        dependencies.each do |dependency|
          resolver = Shards.find_resolver(dependency)

          # FIXME: duplicated from Check#verify
          unless _spec = resolver.installed_spec
            Shards.logger.debug { "#{dependency.name}: not installed" }
            raise Error.new("Dependencies aren't satisfied. Install them with 'shards install'")
          end

          indent = "  " * level
          puts "#{indent}* #{_spec.name} (#{_spec.version})"

          indent_level = tree_mode ? level + 1 : level
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
