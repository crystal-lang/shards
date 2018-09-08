require "./package"

module Shards
  class Manager
    getter spec : Spec
    getter packages : Set
    property locks : Array(Dependency)?

    def initialize(@spec, update_cache = true)
      @packages = Set.new(update_cache: update_cache)
    end

    def resolve
      resolve(spec.dependencies)
      resolve(spec.development_dependencies) unless Shards.production?
    #rescue ex : Conflict
    #  Shards.logger.error ex.message
    #  exit -1
    end

    # TODO: handle conflicts
    def resolve(dependencies)
      dependencies.each do |dependency|
        package = add(dependency)
        resolve(package.spec.dependencies)
      end
    end

    def add(dependency)
      if dependency["branch"]? && (lock = @locks.try(&.find { |d| d.name == dependency.name }))
        # NOTE: if the dependency is a branch refs and we previously locked
        # the dependency, we must declare that locked commit (on install only)
        # otherwise we'd end up resolving the latest branch commit spec that
        # could change dependencies, while still eventually installing the
        # locked commit.
        packages.add(lock)
      end
      packages.add(dependency)
    end

    def to_lock(io : IO)
      io << "version: 1.0\n"
      io << "shards:\n"

      packages
        .sort { |a, b| a.name <=> b.name }
        .each do |package|
          io << "  " << package.name << ":\n"
          package.to_lock(io)
          io << '\n'
        end
    end

    def to_lock(path : String)
      File.open(path, "w") { |file| to_lock(file) }
    end
  end
end
