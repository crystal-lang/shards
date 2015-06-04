require "./resolvers"
require "./helpers/versions"

module Shards
  class Package
    include Helpers::Versions

    getter :requirements

    def initialize(@dependency)
      @requirements = [] of String
    end

    def name
      @dependency.name
    end

    def version
      versions = resolve_versions(available_versions, requirements)

      if versions.any?
        versions.first
      else
        raise Conflict.new(self)
      end
    end

    def spec
      resolver.spec(version)
    end

    def installed?
      resolver.installed?(version)
    end

    def install
      resolver.install(version)
    end

    private def resolver
      @resolver ||= Shards.find_resolver(@dependency)
    end

    private def available_versions
      @available_versions ||= resolver.available_versions
    end
  end

  class Set < Array(Package)
    def add(dependency)
      package = find { |package| package.name == dependency.name }

      unless package
        package = Package.new(dependency)
        self << package
      end

      package.requirements << dependency.version
      package
    end
  end
end
