require "molinillo"

module Shards
  class MolinilloSolver
    setter locks : Array(Dependency)?
    @solution : Array(Package)?

    include Molinillo::SpecificationProvider(Shards::Dependency, Shards::Spec)
    include Molinillo::UI

    def initialize(@spec : Spec, @prereleases = false)
    end

    def prepare(@development = true)
    end

    private def add_lock(base, lock_index, name)
      if lock = lock_index.delete(name)
        resolver = Shards.find_resolver(lock)

        lock_version =
          if version = lock.version?
            version
          else
            versions = resolver.versions_for(lock)
            unless versions.size == 1
              Log.warn { "Lock for shard \"#{name}\" is invalid" }
              return
            end
            versions.first
          end

        lock_dep = Dependency.new(name, version: lock_version)

        # TODO: Remove this once the install command
        #       doesn't rely on the lock version
        lock.version = lock_version

        base.add_vertex(lock.name, lock_dep, true)
        spec = resolver.spec(lock_version)

        spec.dependencies.each do |dep|
          add_lock(base, lock_index, dep.name)
        end
      end
    end

    def solve : Array(Package)
      deps = if @development
               @spec.dependencies + @spec.development_dependencies
             else
               @spec.dependencies
             end

      base = Molinillo::DependencyGraph(Dependency, Dependency).new
      if locks = @locks
        lock_index = locks.to_h { |d| {d.name, d} }

        deps.each do |dep|
          if lock = lock_index[dep.name]?
            if version = lock.version?
              next unless matches?(dep, version)
            end

            add_lock(base, lock_index, dep.name)
          end
        end
      end

      result =
        Molinillo::Resolver(Dependency, Spec)
          .new(self, self)
          .resolve(deps, base)

      packages = [] of Package
      result.each do |v|
        next unless v.payload
        spec = v.payload.as?(Spec) || raise "BUG: returned graph payload was not a Spec"
        v.requirements.each do |dependency|
          unless dependency.name == spec.name
            raise Error.new("Error shard name (#{spec.name}) doesn't match dependency name (#{dependency.name})")
          end
          if spec.mismatched_version?
            Log.warn { "Shard \"#{spec.name}\" version (#{spec.original_version}) doesn't match tag version (#{spec.version})" }
          end
        end
        resolver = spec.resolver || raise "BUG: returned Spec has no resolver"
        version = spec.version

        packages << Package.new(spec.name, resolver, version, nil)
      end

      packages
    end

    def name_for(spec : Shards::Spec)
      spec.resolver.not_nil!.dependency.name
    end

    def name_for(dependency : Shards::Dependency)
      dependency.name
    end

    @search_results = Hash({String, String}, Array(Spec)).new
    @specs = Hash({String, String}, Spec).new

    def search_for(dependency : R) : Array(S)
      @search_results[{dependency.name, dependency.version}] ||= begin
        resolver = Shards.find_resolver(dependency)
        versions = Versions.sort(versions_for(dependency, resolver)).reverse
        result = versions.map do |version|
          @specs[{dependency.name, version}] ||= begin
            resolver.spec(version).tap do |spec|
              spec.version = version
            end
          end
        end

        result
      end
    end

    def name_for_explicit_dependency_source
      SPEC_FILENAME
    end

    def name_for_locking_dependency_source
      LOCK_FILENAME
    end

    def dependencies_for(specification : S) : Array(R)
      specification.dependencies
    end

    def requirement_satisfied_by?(requirement, activated, spec)
      unless @prereleases
        if !spec.version.includes?("+git.commit.") && Versions.prerelease?(spec.version) && !requirement.prerelease?
          vertex = activated.vertex_named(spec.name)
          return false if !vertex || vertex.requirements.none?(&.prerelease?)
        end
      end

      matches?(requirement, spec)
    end

    private def versions_for(dependency, resolver) : Array(String)
      matching = resolver.versions_for(dependency)

      if (locks = @locks) &&
         (locked = locks.find { |dep| dep.name == dependency.name }) &&
         (locked_version = locked.version?) &&
         matches?(dependency, locked_version)
        matching << locked_version
      end

      matching.uniq
    end

    private def matches?(dep : Dependency, spec : Spec)
      matches? dep, spec.version
    end

    private def matches?(dep : Dependency, version : String)
      if dep.refs
        resolver = Shards.find_resolver(dep)
        resolver.matches_ref?(dep, version)
      elsif req_version = dep.version?
        if req_version.includes?("+")
          req_version == version
        else
          Versions.matches?(version, req_version)
        end
      else
        true
      end
    end

    def before_resolution
    end

    def after_resolution
    end

    def indicate_progress
    end
  end
end
