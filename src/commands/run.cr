require "./command"

module Shards
  module Commands
    class Run < Command
      def run(targets, options)
        targets = spec.targets.map(&.name) if targets.empty?
        raise Error.new("Error No targets defined.") if targets.empty?
        raise Error.new("Error More than 1 target defined. Must pass target name as parameter.") if targets.size > 1

        if target = spec.targets.find { |t| t.name == targets.first }
          Commands::Build.run(path, targets, options)
          Shards.logger.info { "Executing: #{target.name}" }

          error = IO::Memory.new
          status = Process.run(File.join(Shards.bin_path, target.name), output: Process::Redirect::Inherit, error: error)
          raise Error.new("Error target #{target.name} failed to run:\n#{error}") unless status.success?
        elsif
          raise Error.new("Error target #{targets.first} not found.")
        end
      end
    end
  end
end
