require "./command"

module Shards
  module Commands
    class Outdated < Command
      @up_to_date = true
      @output = IO::Memory.new

      def self.run(path, @@prereleases = false)
        super
      end

      def run(*args)
        return unless has_dependencies?

        if lockfile?
          manager.locks = locks
          manager.resolve
        else
          manager.resolve
        end

        manager.packages.each do |package|
          analyze(package)
        end

        if @up_to_date
          Shards.logger.info "Dependencies are up to date!"
        else
          @output.rewind
          Shards.logger.warn "Outdated dependencies:"
          puts @output.to_s
        end
      end

      private def analyze(package)
        _spec = package.resolver.installed_spec

        unless _spec
          Shards.logger.warn { "#{package.name}: not installed" }
          return
        end

        installed = _spec.version

        # already the latest version?
        latest = Versions.sort(package.available_versions(@@prereleases)).first
        return if latest == installed

        @up_to_date = false

        @output << "  * " << package.name
        @output << " (installed: " << installed

        # is new version matching constraints available?
        available = package.matching_versions(@@prereleases).first
        unless available == installed
          @output << ", available: " << available
        end

        # also report latest version:
        if Versions.compare(latest, available) < 0
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
