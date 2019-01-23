require "./command"
require "../sat"

module Shards
  module Commands
    class Lock < Command
      record Pkg,
        resolver : Resolver,
        versions : Hash(String, Spec)

      def run
        Shards.logger.info { "Collecting dependencies..." }

        spent = Time.measure do
          dig(spec.dependencies, resolve: true)
          dig(spec.development_dependencies, resolve: true) unless Shards.production?
        end

        Shards.logger.info do
          total = pkgs.reduce(0) { |acc, (_, pkg)| acc + pkg.versions.size }
          "Collected #{pkgs.size} dependencies (total: #{total} specs, duration: #{spent})"
        end

        Shards.logger.info { "Building SAT clauses..." }

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

          # version conflicts (we want only 1 version per package):
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

        Shards.logger.info { "Solving dependencies..." }
        count = 0

        spent = Time.measure do
          sat.solve do |solution|
            # p solution
            count += 1
          end
        end

        if count == 0
          Shards.logger.error { "Failed to find a solution (duration: #{spent})" }
        else
          Shards.logger.info { "Found #{count} solutions (duration: #{spent}" }
        end
      end

      private def sat
        @sat ||= SAT.new
      end

      private def add_dependencies(negation, dependencies)
        dependencies.each do |d|
          versions = Versions.resolve(pkgs[d.name].versions.keys, {d.version})

          # FIXME: looks like we couldn't resolve a constraint here; maybe it's
          # related to a git refs, or something?
          next if versions.empty?

          clause = [negation]
          versions.each { |v| clause << "#{d.name}:#{v}" }
          sat.add_clause(clause)
        end
      end

      private def pkgs
        @pkgs ||= {} of String => Pkg
      end

      private def dig(dependencies, resolve = false)
        dependencies.each do |dependency|
          next if pkgs.has_key?(dependency.name)

          resolver = Shards.find_resolver(dependency)
          versions = resolver.available_versions

          # resolve main spec constraints (avoids useless branches in the dependency graph):
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
