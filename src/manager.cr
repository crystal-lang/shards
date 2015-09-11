require "./package"

module Shards
  class Manager
    getter :spec, :packages, :locks

    def initialize(@spec, update_cache = true)
      @packages = Set.new(update_cache: update_cache)
    end

    def resolve
      resolve(spec)

      unless Shards.production?
        resolve(spec.development_dependencies, recursive: false)
      end
    #rescue ex : Conflict
    #  Shards.logger.error ex.message
    #  exit -1
    end

    def resolve(spec : Spec)
      resolve(spec.dependencies, recursive: true)
    end

    # TODO: handle conflicts
    def resolve(dependencies, recursive = true)
      dependencies.each do |dependency|
        package = packages.add(dependency)
        resolve(package.spec) if recursive
      end
    end

    def to_lock(io : IO)
      io << "version: 1.0\n"
      io << "shards:\n"

      packages
        .sort { |a, b| a.name <=> b.name }
        .each do |package|
          io << "  " << package.name << ":\n"
          package.to_lock(io)
          io << "\n"
        end
    end
  end
end
