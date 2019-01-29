require "./solver/graph"
require "./solver/sat"
require "./spec"

module Shards
  class Solver
    record Result,
      name : String,
      resolver : Resolver,
      version : String,
      commit : String?

    alias Solution = Array(Result)

    getter graph : Graph

    def initialize(@spec : Spec)
      @graph = Graph.new
      @sat = SAT.new
    end

    def prepare(development = true) : Nil
      @graph.add(@spec, development)
      build_cnf_clauses(development)
    end

    def solve : Solution?
      distances = calculate_distances

      solution = nil
      solution_distance = Int32::MAX

      @sat.solve do |proposal|
        # calculate the proposal quality (distance from ideal solution):
        distance = proposal.reduce(0) { |a, e| a + distances[e] }

        if distance < solution_distance
          # select better solution (less distance from ideal):
          solution = proposal.dup
          solution_distance = distance

        elsif distance == solution_distance && proposal.size < solution.not_nil!.size
          # select solution with fewer dependencies (same distance from ideal):
          solution = proposal.dup
          solution_distance = distance
        end
      end

      to_result(solution) if solution
    end

    private def to_result(proposal)
      solution = Solution.new

      proposal.each do |str|
        next unless colon = str.index(':')
        name = str[0...colon]

        if plus = str.index("+git.commit.")
          version = str[(colon + 1)...plus]
          commit = str[(plus + 13)..-1]
        else
          version = str[(colon + 1)..-1]
          commit = nil
        end

        resolver = @graph.packages[name].resolver
        solution << Result.new(name, resolver, version, commit)
      end

      solution
    end

    def each_conflict
      interest = ::Set(String).new
      negation = "~#{@spec.name}"

      @sat.conflicts.reverse_each do |clause|
        if clause.size == 2 && clause.all?(&.starts_with?('~'))
          # version conflict:
          clause[0] =~ /^~(.+):(.+)$/
          a_name, a_version = $1, $2

          clause[1] =~ /:(.+)$/
          b_version = $1

          yield "can't install '#{a_name}' versions #{a_version} and #{b_version} at the same time."
          interest << "#{a_name}:"

        elsif interest.any? { |x| clause.any?(&.starts_with?(x)) }
          # dependency conflict:
          if clause[0] == negation
            spec = @spec
            a_name, a_version = spec.name, nil
          else
            clause[0] =~ /^~(.+):(.+)$/
            a_name, a_version = $1, $2

            spec = graph.packages[a_name].versions[a_version]
            interest << "#{a_name}:"
          end

          clause[1] =~ /^(.+):(.+)$/
          b_name, b_version = $1, $2

          dependency = spec.dependencies.find(&.name.==(b_name)).not_nil!

          yield String.build do |str|
            str << a_name
            str << ' ' << a_version if a_version
            str << " requires " << dependency.name << ' '
            str << dependency.to_human_requirement
          end
        end
      end
    end

    private def build_cnf_clauses(development)
      # the package to install dependencies for:
      @sat.add_clause [@spec.name]

      # main dependencies:
      negation = "~#{@spec.name}"
      add_dependencies(negation, @spec.dependencies)
      add_dependencies(negation, @spec.development_dependencies) if development

      # version conflicts:
      # - we want at most 1 version for each package
      # - defined before dependencies, so any conflict will fail quickly
      @graph.each do |pkg|
        pkg.each_combination do |a, b|
          add_conflict("~#{pkg.name}:#{a}", "~#{pkg.name}:#{b}")
        end
      end

      # nested dependencies:
      @graph.each do |pkg|
        pkg.each do |version, s|
          add_dependencies("~#{pkg.name}:#{version}", s.dependencies)
        end
      end
    end

    private def add_dependencies(negation, dependencies)
      dependencies.each do |d|
        versions = graph.resolve(d)

        if versions.empty?
          # FIXME: we couldn't resolve a constraint
          Shards.logger.warn { "Failed to match versions for #{d.inspect}" }
          next
        end

        clause = [negation]
        versions.each { |v| clause << "#{d.name}:#{v}" }
        @sat.add_clause(clause)
      end
    end

    private def add_conflict(a, b)
      @sat.add_clause [a, b]
    end

    # Computes the distance for each version from a reference version, for
    # deciding the best solution.
    #
    # TODO: should be the distance from a given version or a range of
    #       versions, not necessarily from the latest one (e.g. for
    #       conservative updates).
    # TODO: consider adding some weight (e.g. to update some dependencies).
    private def calculate_distances
      distances = {} of String => Int32
      distances[@spec.name] = 0

      graph.each do |pkg|
        pkg.each_version do |version, index|
          distances["#{pkg.name}:#{version}"] = index
        end
      end

      distances
    end
  end
end
