require "../spec"
require "../lock"
require "../manager"
require "./command"

module Shards
  module Commands
    # OPTIMIZE: avoid updating GIT caches until required
    class Install < Command
      getter :manager, :path

      def initialize(@path)
        spec = Spec.from_file(path)
        @manager = Manager.new(spec)
        @locks = Lock.from_file(lock_file_path) if lock_file?
      end

      def run
        manager.resolve

        if locks = @locks
          install(manager.packages, locks)
        else
          install(manager.packages)
        end

        if generate_lock_file?
          File.open(lock_file_path, "w") { |file| manager.to_lock(file) }
        end
      end

      # TODO: add locks as additional version requirements
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

        if package.installed?(version, loose: true)
          Shards.logger.info "Using #{package.name} (#{version})"
        else
          Shards.logger.info "Installing #{package.name} (#{version})"
          package.install(version)
        end
      end

      private def lock_file?
        File.exists?(lock_file_path)
      end

      private def lock_file_path
        File.join(path, LOCK_FILENAME)
      end

      private def generate_lock_file?
        !Shards.production? &&
          manager.packages.any? &&
          (!lock_file? || outdated_lock_file?)
      end

      private def outdated_lock_file?
        if locks = @locks
          locks.size != manager.packages.size
        else
          false
        end
      end
    end

    def self.install(path = Dir.working_directory)
      Install.new(path).run
    end
  end
end
