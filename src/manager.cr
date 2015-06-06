require "./package"

module Shards
  class Manager
    getter :spec
    getter :packages

    def initialize(@spec, update_cache = true)
      @packages = Set.new(update_cache: update_cache)
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
