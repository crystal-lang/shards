require "./command"
require "../solver"

module Shards
  module Commands
    class Lock < Command
      def run
        solver = Solver.new(spec)
        solver.prepare(development: !Shards.production?)

        if solution = solver.solve
          Shards.logger.info { "Found solution:" }

          puts "version: 1.1"
          puts "shards:"

          solution.sort_by!(&.name).each do |rs|
            key = rs.resolver.class.key

            puts "  #{rs.name}:"
            puts "    #{key}: #{rs.resolver.dependency[key]}"

            if rs.commit
              puts "    commit: #{rs.commit}"
            else
              puts "    version: #{rs.version}" unless rs.commit
            end

            puts
          end
        else
          solver.each_conflict do |message|
            Shards.logger.warn { "Conflict #{message}" }
          end
          Shards.logger.error { "Failed to find a solution" }
        end
      end
    end
  end
end
