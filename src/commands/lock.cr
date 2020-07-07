require "./command"
require "../molinillo_solver"

module Shards
  module Commands
    class Lock < Command
      def run(shards : Array(String), print = false, update = false, *, ignore_crystal_version = false)
        Log.info { "Resolving dependencies" }

        solver = MolinilloSolver.new(spec, override, ignore_crystal_version: ignore_crystal_version)

        if lockfile?
          if update
            # update selected dependencies to latest possible versions, but
            # avoid to update unspecified dependencies, if possible:
            unless shards.empty?
              solver.locks = locks.shards.reject { |d| shards.includes?(d.name) }
            end
          else
            # install must be as conservative as possible:
            solver.locks = locks.shards
          end
        end

        solver.prepare(development: !Shards.production?)

        packages = handle_resolver_errors { solver.solve }
        return if packages.empty?

        if print
          Shards::Lock.write(packages, @override_path, STDOUT)
        else
          write_lockfile(packages)
        end
      end
    end
  end
end
