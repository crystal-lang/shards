require "./command"

module Shards
  module Commands
    class Outdated < Command
      @prereleases = false

      @up_to_date = true
      @output = IO::Memory.new

      def run(@prereleases = false, *, ignore_crystal_version = false)
        return unless has_dependencies?

        Log.info { "Resolving dependencies" }

        solver = MolinilloSolver.new(spec, prereleases: @prereleases, ignore_crystal_version: ignore_crystal_version)
        solver.prepare(development: !Shards.production?)

        packages = handle_resolver_errors { solver.solve }
        packages.each { |package| analyze(package) }

        if @up_to_date
          Log.info { "Dependencies are up to date!" }
        else
          @output.rewind
          Log.warn { "Outdated dependencies:" }
          puts @output.to_s
        end
      end

      private def analyze(package)
        resolver = package.resolver
        installed = resolver.installed_spec.try(&.version)

        unless installed
          Log.warn { "#{package.name}: not installed" }
          return
        end

        # already the latest version?
        available_versions =
          if @prereleases
            resolver.available_releases
          else
            Versions.without_prereleases(resolver.available_releases)
          end
        latest = Versions.sort(available_versions).first
        return if latest == installed

        @up_to_date = false

        @output << "  * " << package.name
        @output << " (installed: " << resolver.report_version(installed)

        unless installed == package.version
          @output << ", available: " << resolver.report_version(package.version)
        end

        # also report latest version:
        if Versions.compare(latest, package.version) < 0
          @output << ", latest: " << resolver.report_version(latest)
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
