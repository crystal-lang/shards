require "./command"

module Shards
  module Commands
    # OPTIMIZE: avoid updating GIT caches until required
    class Install < Command
      def run(*args)
        manager.resolve

        if lockfile?
          install(manager.packages, locks)
        else
          install(manager.packages)
        end

        if generate_lockfile?
          manager.to_lock(lockfile_path)
        end
      end

      private def install(packages : Set, locks : Array(Dependency))
        packages.each do |package|
          version = nil

          if lock = locks.find { |dependency| dependency.name == package.name }
            if version = lock["version"]?
              unless package.matching_versions.includes?(version)
                raise LockConflict.new("#{package.name} requirements changed")
              end
            elsif version = lock["commit"]?
              unless package.matches?(version)
                raise LockConflict.new("#{package.name} requirements changed")
              end
            else
              raise InvalidLock.new # unknown lock resolver
            end
          elsif Shards.production?
            raise LockConflict.new("can't install new dependency #{package.name} in production")
          end

          install(package, version)
        end
      end

      private def install(packages : Set)
        packages.each { |package| install(package) }
      end

      private def install(package : Package, version = nil)
        version ||= package.version

        if package.installed?(version)
          Shards.logger.info "Using #{package.name} (#{package.report_version})"
        else
          Shards.logger.info "Installing #{package.name} (#{package.report_version})"
          package.install(version)
        end
      end

      private def generate_lockfile?
        !Shards.production? && manager.packages.any? && (!lockfile? || outdated_lockfile?)
      end

      private def outdated_lockfile?
        locks.size != manager.packages.size
      end
    end
  end
end
