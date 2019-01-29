require "./command"
require "../solver"

module Shards
  module Commands
    class Lock < Command
      def run(print = false, update = false)
        Shards.logger.info { "Resolving dependencies" }

        solver = Solver.new(spec)
        solver.locks = locks if !update && lockfile?
        solver.prepare(development: !Shards.production?)

        if solution = solver.solve
          if print
            to_lockfile(solution, STDOUT)
          else
            Shards.logger.info { "Writing #{LOCK_FILENAME}" }
            File.open(LOCK_FILENAME, "w") { |file| to_lockfile(solution, file) }
          end
        else
          solver.each_conflict do |message|
            Shards.logger.warn { "Conflict #{message}" }
          end
          Shards.logger.error { "Failed to find a solution" }
        end
      end

      private def to_lockfile(solution, io)
        io << "version: 1.0\n"
        io << "shards:\n"

        solution.sort_by!(&.name).each do |rs|
          key = rs.resolver.class.key

          io << "  " << rs.name << ":\n"
          io << "    " << key << ": " << rs.resolver.dependency[key] << '\n'

          if rs.commit
            io << "    commit: " << rs.commit << '\n'
          else
            io << "    version: " << rs.version << '\n'
          end

          io << '\n'
        end
      end
    end
  end
end
