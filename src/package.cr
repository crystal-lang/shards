require "./resolvers/*"
require "./helpers/versions"

module Shards
  class Package
    include Helpers::Versions

    getter requirements : Array(String)
    @resolver : Resolver?
    @available_versions : Array(String)?

    def initialize(@dependency : Dependency, @update_cache = false)
      @requirements = [] of String
    end

    def name
      @dependency.name
    end

    def version
      if refs = @dependency.refs
        refs
      elsif matching_versions.any?
        matching_versions.first
      else
        raise Conflict.new(self)
      end
    end

    def report_version
      version = self.version
      if version == spec.version
        version
      else
        "#{spec.version} at #{version}"
      end
    end

    def matching_versions
      resolve_versions(available_versions, requirements)
    end

    def spec
      resolver.spec(version)
    end

    def matches?(commit)
      resolver = self.resolver

      if resolver.responds_to?(:matches?)
        resolver.matches?(commit)
      else
        raise LockConflict.new("wrong resolver")
      end
    end

    def installed?(version = self.version)
      if spec = resolver.installed_spec
        resolver.installed_commit_hash == version ||
          spec.version == version
      else
        false
      end
    end

    def install(version = nil)
      resolver.install(version || self.version)
      resolver.run_script("postinstall")
    rescue ex : Script::Error
      resolver.cleanup_install_directory
      raise ex
    end

    def to_lock(io : IO)
      key = resolver.class.key
      io << "    " << key << ": " << @dependency[key] << "\n"

      if @dependency.refs || !(version =~ RELEASE_VERSION)
        io << "    commit: " << resolver.installed_commit_hash.to_s << "\n"
      else
        io << "    version: " << version << "\n"
      end
    end

    def resolver
      @resolver ||= Shards.find_resolver(@dependency, update_cache: @update_cache)
    end

    private def available_versions
      @available_versions ||= resolver.available_versions
    end
  end

  class Set < Array(Package)
    def initialize(@update_cache = true)
      super()
    end

    def add(dependency)
      package = find { |package| package.name == dependency.name }

      unless package
        package = Package.new(dependency, update_cache: @update_cache)
        self << package
      end

      unless dependency.name == package.spec.name
        raise Error.new("Error shard name (#{package.spec.name}) doesn't match dependency name (#{dependency.name})")
      end

      package.requirements << dependency.version
      package
    end
  end
end
