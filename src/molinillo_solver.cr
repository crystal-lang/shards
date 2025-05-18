require "molinillo"
require "./package"

module Shards
  class MolinilloSolver
    setter locks : Array(Package)?
    @solution : Array(Package)?
    @prereleases : Bool

    include Molinillo::SpecificationProvider(Shards::Dependency, Shards::Spec)
    include Molinillo::UI

    def initialize(@spec : Spec, @override : Override? = nil, *, prereleases = false)
      @prereleases = prereleases
    end

    def prepare(@development = true)
    end

    private def add_lock(base, lock_index, dep : Dependency)
      if lock = lock_index.delete(dep.name)
        check_single_resolver_by_name dep.resolver
        base.add_vertex(lock.name, Dependency.new(lock.name, dep.resolver, lock.version), true)

        # Use the resolver from dependencies (not lock) if available.
        # This is to allow changing source without bumping the version when possible.
        if dep.resolver != lock.resolver
          Log.warn { "Ignoring source of \"#{dep.name}\" on shard.lock" }
        end

        spec = begin
          dep.resolver.spec(lock.version)
        rescue ex : Shards::Error
          # If the locked version is not available in the changed source,
          # `shards update` should be used instead of `shards install`.
          message = String.build do |io|
            io << "Locked version #{lock.version} for #{dep.name} was not found in #{dep.resolver}"
            if dep.resolver != lock.resolver
              io << " (locked source is #{lock.resolver})"
            end
            io << ".\n\nPlease run `shards update`"
          end
          raise Shards::Error.new(message, cause: ex)
        end

        add_lock base, lock_index, apply_overrides(spec.dependencies)
      end
    end

    private def prefetch_local_caches(deps)
      return unless Shards.jobs > 1

      count = 0
      active = Atomic.new(0)
      ch = Channel(Exception?).new(deps.size + 1)
      deps.each do |dep|
        count += 1
        active.add(1)
        while active.get > Shards.jobs
          sleep 0.1.seconds
        end
        spawn do
          begin
            Log.with_context do
              Log.context.set package: dep.name
              dep.resolver.update_local_cache if dep.resolver.is_a? GitResolver
            end
            ch.send(nil)
          rescue ex : Exception
            ch.send(ex)
          ensure
            active.sub(1)
          end
        end
      end

      count.times do
        obj = ch.receive
        raise obj if obj.is_a? Exception
      end
    end

    private def add_lock(base, lock_index, deps : Array(Dependency))
      prefetch_local_caches(deps)

      deps.each do |dep|
        if lock = lock_index[dep.name]?
          next unless dep.matches?(lock.version)
          add_lock(base, lock_index, dep)
        end
      end
    end

    def solve : Array(Package)
      deps = if @development
               @spec.dependencies + @spec.development_dependencies
             else
               @spec.dependencies
             end
      deps = apply_overrides(deps)

      prefetch_local_caches(deps)

      base = Molinillo::DependencyGraph(Dependency, Dependency).new
      if locks = @locks
        lock_index = locks.to_h { |d| {d.name, d} }

        add_lock base, lock_index, deps
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

        packages << Package.new(spec.name, resolver, version, !on_override(spec).nil?)
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
      check_single_resolver_by_name dependency.resolver

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

    def on_override(dependency : Dependency | Shards::Spec) : Dependency?
      @override.try(&.dependencies.find { |o| o.name == dependency.name })
    end

    def apply_overrides(deps : Array(Dependency))
      deps.map { |dep| on_override(dep) || dep }
    end

    def name_for_explicit_dependency_source
      SPEC_FILENAME
    end

    def name_for_locking_dependency_source
      LOCK_FILENAME
    end

    def dependencies_for(specification : S) : Array(R)
      apply_overrides(specification.dependencies)
    end

    def self.crystal_version_req(specification : Shards::Spec)
      crystal_pattern =
        if crystal_version = specification.crystal
          if crystal_version =~ /^\d+\.\d+(\.\d+)?$/
            ">= #{crystal_version}"
          else
            crystal_version
          end
        else
          "*"
        end

      VersionReq.new(crystal_pattern)
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
      check_single_resolver_by_name resolver

      matching = resolver.versions_for(dependency.requirement)

      if (locks = @locks) &&
         (locked = locks.find { |dep| dep.name == dependency.name }) &&
         dependency.matches?(locked.version)
        matching << locked.version
      end

      matching.uniq
    end

    def before_resolution
    end

    def after_resolution
    end

    def indicate_progress
    end

    @used_resolvers = {} of String => Resolver

    private def check_single_resolver_by_name(resolver : Resolver)
      if used = @used_resolvers[resolver.name]?
        if used != resolver
          raise Error.new("Error shard name (#{resolver.name}) has ambiguous sources: '#{used.yaml_source_entry}' and '#{resolver.yaml_source_entry}'.")
        end
      else
        @used_resolvers[resolver.name] = resolver
      end
    end
  end
end
