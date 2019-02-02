require "./command"
require "../solver"

module Shards
  module Commands
    class Lock < Command
      def run(shards : Array(String), print = false, update = false)
        Shards.logger.info { "Resolving dependencies" }

        solver = Solver.new(spec)

        if lockfile?
          if update
            # update selected dependencies to latest possible versions, but
            # avoid to update unspecified dependencies, if possible:
            unless shards.empty?
              solver.locks = locks.reject { |d| shards.includes?(d.name) }
            end
          else
            # install must be as conservative as possible:
            solver.locks = locks
          end
        end

        solver.prepare(development: !Shards.production?)

        if packages = solver.solve
          if print
            Shards::Lock.write(packages, STDOUT)
          else
            write_lockfile(packages)
          end
        else
          solver.each_conflict do |message|
            Shards.logger.warn { "Conflict #{message}" }
          end
          Shards.logger.error { "Failed to resolve dependencies" }
        end
      end

      private def to_lockfile(packages, io)
        io << "version: 1.0\n"
        io << "shards:\n"

        packages.sort_by!(&.name).each do |package|
          key = package.resolver.class.key

          io << "  " << package.name << ":\n"
          io << "    " << key << ": " << package.resolver.dependency[key] << '\n'

          if package.commit
            io << "    commit: " << package.commit << '\n'
          else
            io << "    version: " << package.version << '\n'
          end

          io << '\n'
        end
      end
    end
  end
end
