require "./dependency"
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
      versions = resolve_versions(resolver.available_versions, requirements)

      if versions.any?
        versions.first
      else
        raise Conflict.new(self)
      end
    end

    def spec
      resolver.spec(version)
    end

    def install
      resolver.install(version)
    end

    private def resolver
      @resolver ||= Shards.find_resolver(@dependency)
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

  class Manager
    getter :spec
    getter :packages

    def initialize(@spec)
      @packages = Set.new
    end

    def resolve
      resolve(spec)
    rescue ex : Conflict
      Shards.logger.error ex.message
      exit -1
    end

    # TODO: handle conflicts
    def resolve(spec)
      spec.dependencies.each do |dependency|
        package = packages.add(dependency)
        resolve(package.spec)
      end
    end
  end
end
