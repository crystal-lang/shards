require "./package"
require "./solver/graph"
require "./solver/sat"
require "./spec"

module Shards
  class Solver
    setter locks : Array(Dependency)?
    @solution : Array(Package)?

    def initialize(@spec : Spec, @prereleases = false)
      @graph = Graph.new
      @sat = SAT.new
      @solution = nil
      @solution_distance = Int32::MAX
    end

    def prepare(development = true) : Nil
      @graph.add(@spec, development)

      if locks = @locks
        locks.each do |lock|
          if lock["commit"]?
            @graph.add(lock)
          end
        end
      end

      build_cnf_clauses(development)
    end

    def solve : Array(Package)?
      distances = calculate_distances

      @sat.solve do |proposal|
        # calculate the proposal quality (distance from ideal solution):
        distance = proposal.reduce(0) { |a, e| a + distances[e] }

        if distance < @solution_distance
          # select better solution (less distance from ideal):
          consider(proposal, distance)

        elsif distance == @solution_distance && proposal.size < @solution.not_nil!.size
          # select solution with fewer dependencies (same distance from ideal):
          consider(proposal, distance)
        end
      end

      @solution
    end

    private def consider(proposal, distance)
      packages = to_packages(proposal)

      # pre-releases are opt-in, so we must check that the solution didn't
      # select one unless at least one requirement in the selected graph asked
      # for it, or we install the dependency at a Git refs:
      unless @prereleases
        packages.each do |package|
          next unless Versions.prerelease?(package.version)
          next if package.commit

          if dependency = @spec.dependencies.find { |d| d.name == package.name }
            break if Versions.prerelease?(dependency.version)
          end

          return unless packages.any? do |pkg|
            if dependency = pkg.spec.dependencies.find { |d| d.name == package.name }
              Versions.prerelease?(dependency.version)
            end
          end
        end
      end

      # solution is acceptable:
      @solution = packages
      @solution_distance = distance
    end

    private def to_packages(solution)
      packages = [] of Package

      solution.each do |str|
        next unless colon = str.index(':')
        name = str[0...colon]

        if plus = str.index("+git.commit.")
          version = str[(colon + 1)...plus]
          commit = str[(plus + 12)..-1]
        else
          version = str[(colon + 1)..-1]
          commit = nil
        end

        resolver = @graph.packages[name].resolver
        packages << Package.new(name, resolver, version, commit)
      end

      packages
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

            spec = @graph.packages[a_name].versions[a_version]
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
        versions = @graph.resolve(d)

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
    private def calculate_distances
      distances = {} of String => Int32
      distances[@spec.name] = 0

      @graph.each do |pkg|
        # reference is latest version by default:
        position = 0

        if locked = @locks.try(&.find { |d| d.name == pkg.name })
          # determine position of locked version to use it as reference:
          pkg.each_version do |version, index|
            if version == locked.version || ((commit = locked["commit"]?) && version.ends_with?("+git.commit.#{commit}"))
              position = index
              break
            end
          end
        end

        # calculate distances to reference version:
        pkg.each_version do |version, index|
          distances["#{pkg.name}:#{version}"] = (position - index).abs
        end
      end

      distances
    end
  end
end
