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
          total = pkgs.reduce(0) { |acc, (name, pkg)| acc + pkg.versions.size }
          "Collected #{pkgs.size} dependencies (total: #{total} specs, duration: #{spent})"
        end

        sat = Shards::SAT.new

        Shards.logger.info { "Building SAT clauses..." }

        spent = Time.measure do
          negation = "~#{spec.name}"

          # the package to install dependencies for:
          sat.add_clause [spec.name]

          # main dependencies:
          spec.dependencies.each do |d|
            clause = [negation]
            Versions
              .resolve(pkgs[d.name].versions.keys, {d.version})
              .each { |v| clause << "#{d.name}:#{v}" }
            sat.add_clause(clause)
          end

          # nested dependencies:
          pkgs.each do |name, pkg|
            pkg.versions.each do |version, s|
              s.dependencies.each do |d|
                clause = ["~#{name}:#{version}"]
                Versions
                  .resolve(pkgs[d.name].versions.keys, {d.version})
                  .map { |v| clause << "#{d.name}:#{v}" }
                sat.add_clause(clause) unless clause.size == 1
              end
            end
          end

          # version conflicts (only 1 version per package)
          pkgs.each do |name, pkg|
            pkg.versions.keys.each_combination(2) do |(a, b)|
              sat.add_clause ["~#{name}:#{a}", "~#{name}:#{b}"]
            end
          end
        end
        Shards.logger.info { "Built #{sat.@clauses.size} clauses (duration: #{spent})" }

        sat.@clauses.each do |clause|
          STDERR.puts sat.clause_to_s(clause)
        end

        Shards.logger.info { "Solving dependencies..." }
        count = 0

        spent = Time.measure do
          sat.solve do |solution|
            # p solution
            count += 1
            print "found: #{count} solutions\r" if count == 100
          end
        end
        print "found: #{count} solutions\n"

        if count == 0
          Shards.logger.error { "Failed to find a solution (duration: #{spent})" }
        else
          Shards.logger.info { "Found #{count} solutions (duration: #{spent}" }
        end
      end

      protected def sat
        @sat ||= SAT.new
      end

      protected def pkgs
        @pkgs ||= {} of String => Pkg
      end

      protected def dig(dependencies, resolve = false)
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
            dig(spec.development_dependencies) unless Shards.production?
          end
        end
      end
    end
  end
end
