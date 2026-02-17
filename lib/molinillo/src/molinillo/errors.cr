require "./delegates/specification_provider"

module Molinillo
  # An error that occurred during the resolution process
  class ResolverError < Exception; end

  # An error caused by searching for a dependency that is completely unknown,
  # i.e. has no versions available whatsoever.
  class NoSuchDependencyError < ResolverError
    # @return [Object] the dependency that could not be found
    getter dependency : String

    # @return [Array<Object>] the specifications that depended upon {#dependency}
    getter required_by : Array(String)

    # Initializes a new error with the given missing dependency.
    # @param [Object] dependency @see {#dependency}
    # @param [Array<Object>] required_by @see {#required_by}
    def initialize(dependency, required_by = [] of S)
      @dependency = dependency
      @required_by = required_by.uniq
      super
    end

    # The error message for the missing dependency, including the specifications
    # that had this dependency.
    def message
      sources = required_by.join(" and ") { |r| "`#{r}`" }
      message = "Unable to find a specification for `#{dependency}`"
      message += " depended upon by #{sources}" unless sources.empty?
      message
    end
  end

  # An error caused by attempting to fulfil a dependency that was circular
  #
  # @note This exception will be thrown iff a {Vertex} is added to a
  #   {DependencyGraph} that has a {DependencyGraph::Vertex#path_to?} an
  #   existing {DependencyGraph::Vertex}
  class CircularDependencyError(P, R) < ResolverError
    # [Set<Object>] the dependencies responsible for causing the error
    getter vertices : Array(DependencyGraph::Vertex(P, R))

    # Initializes a new error with the given circular vertices.
    # @param [Array<DependencyGraph::Vertex>] vertices the vertices in the dependency
    #   that caused the error
    def initialize(@vertices)
      super "There is a circular dependency between #{vertices.join(" and ", &.name)}"
      # @dependencies = vertices.map { |vertex| vertex.payload.possibilities.last }.to_set
    end
  end

  # An error caused by conflicts in version
  class VersionConflict(R, S) < ResolverError
    # @return [{String => Resolution::Conflict}] the conflicts that caused
    #   resolution to fail
    getter conflicts : Hash(String, Resolver::Resolution::Conflict(R, S))

    # @return [SpecificationProvider] the specification provider used during
    #   resolution
    getter specification_provider : SpecificationProvider(R, S)

    # Initializes a new error with the given version conflicts.
    # @param [{String => Resolution::Conflict}] conflicts see {#conflicts}
    # @param [SpecificationProvider] specification_provider see {#specification_provider}
    def initialize(conflicts, specification_provider)
      pairs = [] of {R, S | String}
      conflicts.values.flatten.flat_map(&.requirements).each do |conflicting|
        conflicting.each do |source, conflict_requirements|
          conflict_requirements.each do |c|
            pairs << {c, source}
          end
        end
      end

      super "Unable to satisfy the following requirements:\n\n" \
            "#{pairs.join('\n') { |r, d| "- `#{r}` required by `#{d}`" }}"

      @conflicts = conflicts
      @specification_provider = specification_provider
    end

    include Delegates::SpecificationProvider
  end
end
