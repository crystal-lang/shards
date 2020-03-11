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

    def solve : Array(Package)
      deps = if @development
               @spec.dependencies + @spec.development_dependencies
             else
               @spec.dependencies
             end

      base = Molinillo::DependencyGraph(Dependency, Dependency).new
      if locks = @locks
        locks.each do |lock|
          if version = lock["version"]?
            dep = deps.find { |d| d.name == lock.name }
            next if dep && !Versions.matches?(version, dep.version)
          end

          if commit = lock["commit"]?
            resolver = Shards.find_resolver(lock)
            spec = resolver.spec(commit)
            lock["version"] = "#{spec.version}+git.commit.#{commit}"
          end
          base.add_vertex(lock.name, lock, true)
        end
      end

      result =
        Molinillo::Resolver(Dependency, Spec)
          .new(self, self)
          .resolve(deps, base)

      packages = [] of Package
      result.each do |v|
        spec = v.payload.as(Spec) || raise "BUG: returned graph payload was not a Spec"
        v.requirements.each do |dependency|
          unless dependency.name == spec.name
            raise Error.new("Error shard name (#{spec.name}) doesn't match dependency name (#{dependency.name})")
          end
        end
        resolver = spec.resolver || raise "BUG: returned Spec has no resolver"
        version = spec.version

        if plus = version.index("+git.commit.")
          commit = version[(plus + 12)..-1]
          version = version[0...plus]
        end

        packages << Package.new(spec.name, resolver, version, commit)
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

      Versions.matches?(spec.version, requirement.version)
    end

    private def versions_for(dependency, resolver) : Array(String)
      matching =
        if requirement = dependency.version?
          if requirement == "HEAD"
            return versions_for_refs("HEAD", dependency, resolver)
          else
            Versions.resolve(resolver.available_versions, requirement)
          end
        elsif refs = dependency.refs
          versions_for_refs(refs, dependency, resolver)
        else
          resolver.available_versions
        end

      if (locks = @locks) && (locked = locks.find { |dep| dep.name == dependency.name })
        matching << locked.version
      end

      if matching.size == 1 && matching.first == "HEAD"
        # NOTE: dependency doesn't have any version number tag, and defaults
        #       to [HEAD], we must resolve the refs to an actual version:
        versions_for_refs("HEAD", dependency, resolver)
      else
        matching
      end
    end

    private def versions_for_refs(refs, dependency, resolver : GitResolver) : Array(String)
      if version = resolver.version_at(refs)
        ["#{version}+git.commit.#{resolver.commit_sha1_at(refs)}"]
      else
        raise Error.new "Failed to find #{dependency.name} version for git refs=#{refs}"
      end
    end

    private def versions_for_refs(refs, dependency, resolver) : NoReturn
      raise "unreachable"
    end

    def before_resolution
    end

    def after_resolution
    end

    def indicate_progress
    end
  end
end
