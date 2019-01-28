require "./command"
require "../sat"
require "../dependency_graph"

module Shards
  module Commands
    class Lock < Command
      private def graph
        @graph ||= DependencyGraph.new
      end

      private def sat
        @sat ||= SAT.new
      end

      def run
        # 1. build dependency graph:
        Shards.logger.info { "Building dependency graph" }

        spent = Time.measure do
          graph.add(spec, development: !Shards.production?)
        end

        Shards.logger.debug do
          total = graph.packages.reduce(0) { |acc, (_, pkg)| acc + pkg.versions.size }
          "Collected #{graph.packages.size} dependencies (#{total} specs, duration: #{spent})"
        end

        # 2. translate dependency graph as CNF clauses (conjunctive normal form):
        spent = Time.measure do
          # the package to install dependencies for:
          sat.add_clause [spec.name]

          # main dependencies:
          negation = "~#{spec.name}"
          add_dependencies(negation, spec.dependencies)
          add_dependencies(negation, spec.development_dependencies) unless Shards.production?

          # version conflicts:
          # - we want at most 1 version for each package
          # - defined before dependencies, so any conflict will fail quickly
          graph.each do |pkg|
            pkg.each_combination do |a, b|
              sat.add_clause ["~#{pkg.name}:#{a}", "~#{pkg.name}:#{b}"]
            end
          end

          # nested dependencies:
          graph.each do |pkg|
            pkg.each do |version, s|
              add_dependencies("~#{pkg.name}:#{version}", s.dependencies)
            end
          end
        end
        Shards.logger.debug { "Built #{sat.@clauses.size} clauses (duration: #{spent})" }

        # STDERR.puts "VARIABLES:"
        # sat.@variables.each do |variable|
        #   STDERR.puts variable
        # end

        # STDERR.puts "\nCLAUSES:"
        # sat.@clauses.each do |clause|
        #   STDERR.puts sat.clause_to_s(clause)
        # end

        # 3. distances (for decision making)
        # compute distance for each version from a reference version:
        distances = {} of String => Int32
        distances[spec.name] = 0

        # TODO: should be the distance from a given version or a range of
        #       versions, not necessarily from the latest one (e.g. for
        #       conservative updates).
        # TODO: consider adding some weight (e.g. to update some dependencies).
        graph.each do |pkg|
          pkg.each_version do |version, index|
            distances["#{pkg.name}:#{version}"] = index
          end
        end

        # 4. solving + decision
        # FIXME: some nested dependencies seem to be selected despite being extraneous (missing clauses?)
        Shards.logger.info { "Solving dependencies" }
        count = 0

        solution = nil
        solution_distance = Int32::MAX

        spent = Time.measure do
          sat.solve do |proposal|
            count += 1

            # 4 (bis). decision making
            # decide the proposal quality (most up-to-date):
            distance = proposal.reduce(0) { |a, e| a + distances[e] }

            # better solution?
            if distance < solution_distance
              solution = proposal.dup
              solution_distance = distance

              Shards.logger.debug do
                "Select proposal (distance=#{solution_distance}): #{solution.sort.join(' ')}"
              end

            # fewer dependencies?
            elsif distance == solution_distance && proposal.size < solution.not_nil!.size
              solution = proposal.dup
              solution_distance = distance

              Shards.logger.debug do
                "Select smaller proposal (distance=#{solution_distance}): #{solution.sort.join(' ')}"
              end
            end
          end
        end

        # 5.
        if solution
          Shards.logger.debug { "Analyzed #{count} solutions (duration: #{spent}" }
          Shards.logger.info { "Found solution:" }

          solution
            .compact_map { |variable| variable.split(':') if variable.index(':') }
            .sort { |a, b| a[0] <=> b[0] }
            .each { |p| puts "  #{p[0]}: #{p[1]}" }
        else
          report_conflicts

          if Shards.logger.debug?
            Shards.logger.error { "Failed to find a solution (duration: #{spent})" }
          else
            Shards.logger.error { "Failed to find a solution" }
          end
        end
      end

      private def add_dependencies(negation, dependencies)
        dependencies.each do |d|
          versions = graph.resolve(d)

          if versions.empty?
            # FIXME: we couldn't resolve a constraint (likely a git refs)
            Shards.logger.warn { "Failed to match versions for #{d.inspect}" }
            next
          end

          clause = [negation]
          versions.each { |v| clause << "#{d.name}:#{v}" }
          sat.add_clause(clause)
        end
      end

      private def report_conflicts
        interest = ::Set(String).new
        negation = "~#{self.spec.name}"

        sat.conflicts.reverse_each do |clause|
          if clause.size == 2 && clause.all?(&.starts_with?('~'))
            # version conflict:
            clause[0] =~ /^~(.+):(.+)$/
            a_name, a_version = $1, $2

            clause[1] =~ /:(.+)$/
            b_version = $1

            Shards.logger.warn do
              "Conflict can't install '#{a_name}' versions #{a_version} and #{b_version} at the same time."
            end
            interest << "#{a_name}:"

          elsif interest.any? { |x| clause.any?(&.starts_with?(x)) }
            # dependency graph conflict:
            if clause[0] == negation
              spec = self.spec
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

            Shards.logger.warn do
              human = dependency.to_human_requirement

              String.build do |str|
                str << "Conflict " << a_name
                str << ' ' << a_version if a_version
                str << " requires " << dependency.name << ' '
                str << human
                # str << " (selected " << b_version << ')' unless human == b_version
              end
            end
          end
        end
      end
    end
  end
end
