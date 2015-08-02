require "./package"

module Shards
  class Manager
    getter :spec, :packages

    def initialize(@spec, @groups = nil, update_cache = true)
      @packages = Set.new(update_cache: update_cache)
    end

    def resolve
      resolve(spec)
    rescue ex : Conflict
      Shards.logger.error ex.message
      exit -1
    end

    def resolve(spec : Spec)
      resolve(spec.dependencies, recursive: true)

      if groups = @groups
        groups.each do |group|
          if dependencies = spec["#{ group }_dependencies"]
            resolve(dependencies, recursive: false)
          end
        end
      end
    end

    # TODO: handle conflicts
    def resolve(dependencies, recursive = true)
      dependencies.each do |dependency|
        package = packages.add(dependency)
        resolve(package.spec) if recursive
      end
    end
  end
end
