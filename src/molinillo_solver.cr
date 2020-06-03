require "molinillo"
require "./package"

module Shards
  class MolinilloSolver
    setter locks : Array(Dependency)?
    @solution : Array(Package)?
    @prereleases : Bool
    @ignore_crystal_version : Bool

    include Molinillo::SpecificationProvider(Shards::Dependency, Shards::Spec)
    include Molinillo::UI

    def initialize(@spec : Spec, *, prereleases = false, ignore_crystal_version = false)
      @prereleases = prereleases
      @ignore_crystal_version = ignore_crystal_version
    end

    def prepare(@development = true)
    end

    private def add_lock(base, lock_index, name)
      if lock = lock_index.delete(name)
        resolver = lock.resolver

        lock_version =
          case lock_req = lock.requirement
          when Version then lock_req
          else
            versions = resolver.versions_for(lock_req)
            unless versions.size == 1
              Log.warn { "Lock for shard \"#{name}\" is invalid" }
              return
            end
            lock.requirement = versions.first
          end

        base.add_vertex(lock.name, lock, true)
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
            if version = lock.requirement.as?(Version)
              next unless dep.matches?(version)
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
      tsort(result).each do |v|
        next unless v.payload
        spec = v.payload.as?(Spec) || raise "BUG: returned graph payload was not a Spec"
        next if spec.name == "crystal"
        v.requirements.each do |dependency|
          unless dependency.name == spec.name
            raise Error.new("Error shard name (#{spec.name}) doesn't match dependency name (#{dependency.name})")
          end
          if spec.read_from_yaml?
            if spec.mismatched_version?
              Log.warn { "Shard \"#{spec.name}\" version (#{spec.original_version.value}) doesn't match tag version (#{spec.version.value})" }
            end
          else
            Log.warn { "Shard \"#{spec.name}\" version (#{spec.version}) doesn't have a shard.yml file" }
          end
        end
        resolver = spec.resolver || raise "BUG: returned Spec has no resolver"
        version = spec.version

        packages << Package.new(spec.name, resolver, version)
      end

      packages
    end

    private def tsort(graph)
      sorted_vertices = typeof(graph.vertices).new

      graph.vertices.values.each do |vertex|
        if vertex.incoming_edges.empty?
          tsort_visit(vertex, sorted_vertices)
        end
      end

      sorted_vertices.values
    end

    private def tsort_visit(vertex, sorted_vertices)
      vertex.successors.each do |succ|
        unless sorted_vertices.has_key?(succ.name)
          tsort_visit(succ, sorted_vertices)
        end
      end

      sorted_vertices[vertex.name] = vertex
    end

    def name_for(spec : Shards::Spec)
      spec.resolver.not_nil!.name
    end

    def name_for(dependency : Shards::Dependency)
      dependency.name
    end

    @search_results = Hash({String, Requirement}, Array(Spec)).new
    @specs = Hash({String, Version}, Spec).new

    def search_for(dependency : R) : Array(S)
      @search_results[{dependency.name, dependency.requirement}] ||= begin
        resolver = dependency.resolver
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
      return specification.dependencies if specification.name == "crystal"
      return specification.dependencies if @ignore_crystal_version

      crystal_pattern =
        if crystal_version = specification.crystal
          if crystal_version =~ /^(\d+)\.(\d+)\.(\d+)$/
            "~> #{$1}.#{$2}, >= #{crystal_version}"
          else
            crystal_version
          end
        else
          "< 1.0.0"
        end
      crystal_dependency = Dependency.new("crystal", CrystalResolver::INSTANCE, VersionReq.new(crystal_pattern))

      specification.dependencies + [crystal_dependency]
    end

    def requirement_satisfied_by?(dependency, activated, spec)
      unless @prereleases
        if !spec.version.has_metadata? && spec.version.prerelease? && !dependency.prerelease?
          vertex = activated.vertex_named(spec.name)
          return false if !vertex || vertex.requirements.none?(&.prerelease?)
        end
      end

      dependency.matches?(spec.version)
    end

    private def versions_for(dependency, resolver) : Array(Version)
      matching = resolver.versions_for(dependency.requirement)

      if (locks = @locks) &&
         (locked = locks.find { |dep| dep.name == dependency.name }) &&
         (locked_version = locked.requirement.as?(Version)) &&
         dependency.matches?(locked_version)
        matching << locked_version
      end

      matching.uniq
    end

    def before_resolution
    end

    def after_resolution
    end

    def indicate_progress
    end
  end
end
