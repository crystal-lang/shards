require "./command"
require "../sat"

module Shards
  module Commands
    class Lock < Command
      record Pkg,
        resolver : Resolver,
        versions : Hash(String, Spec)

      private def sat
        @sat ||= SAT.new
      end

      private def pkgs
        @pkgs ||= {} of String => Pkg
      end

      def run
        # 1. build dependency graph:
        Shards.logger.info { "Collecting dependencies..." }

        spent = Time.measure do
          dig(spec.dependencies, resolve: true)
          dig(spec.development_dependencies, resolve: true) unless Shards.production?
        end

        Shards.logger.info do
          total = pkgs.reduce(0) { |acc, (_, pkg)| acc + pkg.versions.size }
          "Collected #{pkgs.size} dependencies (total: #{total} specs, duration: #{spent})"
        end

        # 2. translate dependency graph as CNF clauses (conjunctive normal form):
        Shards.logger.debug { "Building clauses..." }

        spent = Time.measure do
          # the package to install dependencies for:
          sat.add_clause [spec.name]

          # main dependencies:
          negation = "~#{spec.name}"
          add_dependencies(negation, spec.dependencies)
          add_dependencies(negation, spec.development_dependencies) unless Shards.production?

          # nested dependencies:
          pkgs.each do |name, pkg|
            pkg.versions.each do |version, s|
              add_dependencies("~#{name}:#{version}", s.dependencies)
            end
          end

          # version conflicts (we want at most 1 version for each package):
          pkgs.each do |name, pkg|
            pkg.versions.keys.each_combination(2) do |(a, b)|
              sat.add_clause ["~#{name}:#{a}", "~#{name}:#{b}"]
            end
          end
        end
        Shards.logger.info { "Built #{sat.@clauses.size} clauses (duration: #{spent})" }

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
        pkgs.each do |name, pkg|
          pkg.versions.keys.each_with_index do |version, index|
            distances["#{name}:#{version}"] = index
          end
        end

        # 4. solving + decision
        # FIXME: some nested dependencies seem to be selected despite being extraneous (missing clauses?)
        Shards.logger.info { "Solving dependencies..." }
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
              Shards.logger.debug { "Select proposal (distance=#{solution_distance}): #{solution.sort.join(' ')}" }

            # fewer dependencies?
            elsif distance == solution_distance && proposal.size < solution.not_nil!.size
              solution = proposal.dup
              solution_distance = distance
              Shards.logger.debug { "Select smaller proposal (distance=#{solution_distance}): #{solution.sort.join(' ')}" }
            end
          end
        end

        # 5.
        if solution
          Shards.logger.info { "Analyzed #{count} solutions (duration: #{spent}" }
          Shards.logger.info { "Found solution:" }
          solution
            .compact_map { |variable| variable.split(':') if variable.index(':') }
            .sort { |a, b| a[0] <=> b[0] }
            .each { |p| puts "#{p[0]}: #{p[1]}" }
        else
          Shards.logger.error { "Failed to find a solution (duration: #{spent})" }
        end
      end

      private def add_dependencies(negation, dependencies)
        dependencies.each do |d|
          versions = Versions.resolve(pkgs[d.name].versions.keys, {d.version})

          # FIXME: looks like we couldn't resolve a constraint here; maybe it's
          #        related to a git refs?
          next if versions.empty?

          clause = [negation]
          versions.each { |v| clause << "#{d.name}:#{v}" }
          sat.add_clause(clause)
        end
      end

      # TODO: try and limit versions to what's actually reachable, in order to
      #       reduce the dependency graph, which will reduce the number of
      #       solutions, thus reduce the overall solving time.
      private def dig(dependencies, resolve = false)
        dependencies.each do |dependency|
          next if pkgs.has_key?(dependency.name)

          resolver = Shards.find_resolver(dependency)
          versions = resolver.available_versions

          # resolve main spec constraints (avoids impossible branches in the
          # dependency graph):
          versions = Versions.resolve(versions, {dependency.version}) if resolve

          pkg = Pkg.new(resolver, resolver.specs(Versions.sort(versions)))
          pkgs[dependency.name] = pkg

          pkg.versions.each do |version, spec|
            next unless version =~ VERSION_REFERENCE
            dig(spec.dependencies)
          end
        end
      end
    end
  end
end
