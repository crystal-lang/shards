module Shards
  class Solver
    class Graph
      struct Pkg
        getter name : String
        getter resolver : Resolver
        getter versions : Hash(String, Spec)

        def initialize(dependency : Dependency)
          @name = dependency.name
          @resolver = Shards.find_resolver(dependency)
          @versions = {} of String => Spec
        end

        def each
          @versions.each { |v, s| yield v, s }
        end

        def each_version
          Versions
            .sort(@versions.keys)
            .each_with_index { |v, i| yield v, i }
        end

        def each_combination
          @versions.keys.each_combination(2) { |(a, b)| yield a, b }
        end

        def resolve(requirement)
          Versions.sort(Versions.resolve(@versions.keys, requirement))
        end
      end

      getter packages : Hash(String, Pkg)

      def initialize
        @packages = {} of String => Pkg
      end

      def each
        @packages.each_value { |pkg| yield pkg }
      end

      def resolve(dependency : Dependency)
        @packages[dependency.name].resolve(dependency.version)
      end

      def add(spec : Spec, development = false)
        spec.dependencies.each { |dependency| add(dependency) }
        spec.development_dependencies.each { |dependency| add(dependency) } if development
      end

      private def add(dependency : Dependency)
        pkg = @packages[dependency.name] ||= Pkg.new(dependency)
        resolver = pkg.resolver

        versions_for(dependency, resolver).each do |version|
          next if pkg.versions.has_key?(version)

          if spec = resolver.spec?(version)
            unless dependency.name == spec.name
              raise Error.new("Error shard name (#{spec.name}) doesn't match dependency name (#{dependency.name})")
            end

            pkg.versions[version] = spec
            add(spec)
          else
            # skip (e.g. missing shard.yml)
          end
        end
      end

      private def versions_for(dependency, resolver) : Array(String)
        if requirement = dependency.version?
          if requirement == "HEAD"
            versions_for_refs("HEAD", dependency, resolver)
          else
            Versions.resolve(resolver.available_versions, requirement)
          end
        elsif refs = dependency.refs
          versions_for_refs(refs, dependency, resolver)
        else
          resolver.available_versions
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
    end
  end
end
