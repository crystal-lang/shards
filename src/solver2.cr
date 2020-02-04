require "molinillo"

module Shards
  class Solver2
    setter locks : Array(Dependency)?
    @solution : Array(Package)?

    include Molinillo::SpecificationProvider(Shards::Dependency, Shards::Spec)
    include Molinillo::UI

    def initialize(@spec : Spec, @prereleases = false)
    end

    def prepare(development = true)
    end

    def solve : Array(Package)
      result =
        Molinillo::Resolver(Dependency, Spec)
          .new(self, self)
          .resolve(@spec.dependencies)

      puts result.to_dot

      [] of Package
    end

    def each_conflict(&block)
      raise "not implemented"
    end

    def name_for(dependency)
      dependency.name
    end

    @specs = Hash(String, Array(Spec)).new

    def search_for(dependency : R) : Array(S)
      specs = @specs.fetch(dependency.name) do
        @specs[dependency.name] =
          begin
            resolver = Shards.find_resolver(dependency)
            versions = Versions.sort(resolver.available_versions).reverse
            resolver.specs(versions).map do |version, spec|
              spec.version = version
              spec
            end
          end
      end

      result = specs.select { |v| Versions.matches?(v.version, dependency.version) }

      result
    end

    def dependencies_for(specification : S) : Array(R)
      specification.dependencies
    end

    def requirement_satisfied_by?(requirement, activated, spec)
      Versions.matches?(spec.version, requirement.version)
    end
  end
end
