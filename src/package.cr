require "./resolvers/*"
require "./helpers/versions"

module Shards
  class Package
    include Helpers::Versions

    getter :requirements

    def initialize(@dependency, @update_cache = false)
      @requirements = [] of String
    end

    def name
      @dependency.name
    end

    def version
      if matching_versions.any?
        matching_versions.first
      else
        raise Conflict.new(self)
      end
    end

    def matching_versions
      resolve_versions(available_versions, requirements)
    end

    def spec
      resolver.spec(version)
    end

    def installed?(loose = false)
      if spec = resolver.installed_spec
        if loose
          matching_versions.includes?(spec.version)
        else
          version == spec.version
        end
      else
        false
      end
    end

    def install
      resolver.install(version)
    end

    private def resolver
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

      package.requirements << dependency.version
      package
    end
  end
end
