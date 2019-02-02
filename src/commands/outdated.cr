require "./command"

module Shards
  module Commands
    class Outdated < Command
      @prereleases = false

      @up_to_date = true
      @output = IO::Memory.new

      def run(@prereleases = false)
        return unless has_dependencies?

        Shards.logger.info { "Resolving dependencies" }

        solver = Solver.new(spec)
        solver.prepare(development: !Shards.production?)

        if packages = solver.solve
          packages.each { |package| analyze(package) }

          if @up_to_date
            Shards.logger.info "Dependencies are up to date!"
          else
            @output.rewind
            Shards.logger.warn "Outdated dependencies:"
            puts @output.to_s
          end
        else
          solver.each_conflict do |message|
            Shards.logger.warn { "Conflict #{message}" }
          end
          Shards.logger.error { "Failed to resolve dependencies" }
        end
      end

      private def analyze(package)
        resolver = package.resolver
        installed = resolver.installed_spec.try(&.version)

        unless installed
          Shards.logger.warn { "#{package.name}: not installed" }
          return
        end

        # already the latest version?
        available_versions =
          if @prereleases
            resolver.available_versions
          else
            Versions.without_prereleases(resolver.available_versions)
          end
        latest = Versions.sort(available_versions).first
        return if latest == installed

        @up_to_date = false

        @output << "  * " << package.name
        @output << " (installed: " << installed

        unless installed == package.version
          @output << ", available: " << package.version
        end

        # also report latest version:
        if Versions.compare(latest, package.version) < 0
          @output << ", latest: " << latest
        end

        @output.puts ')'
      end

      # FIXME: duplicates Check#has_dependencies?
      private def has_dependencies?
        spec.dependencies.any? || (!Shards.production? && spec.development_dependencies.any?)
      end
    end
  end
end
