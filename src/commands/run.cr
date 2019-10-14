require "./command"

module Shards
  module Commands
    class Run < Command
      def run(targets, options, run_options)
        specific_target_requested = true
        if targets.empty?
          specific_target_requested = false
          targets = spec.targets.map(&.name)
        end

        raise Error.new("Error No targets defined.") if targets.empty?

        if targets.size > 1
          if specific_target_requested
            raise Error.new("Error Please specify only one target. If you meant to pass arguments you may use: shards run target -- args.")
          elsif
            raise Error.new("Error More than 1 target defined. Please specify what target you want to run.")
          end
        end

        if target = spec.targets.find { |t| t.name == targets.first }
          Commands::Build.run(path, targets, options)
          Shards.logger.info { "Executing: #{target.name} #{run_options.join(' ')}" }

          error = IO::Memory.new
          status = Process.run(File.join(Shards.bin_path, target.name), args: run_options, output: Process::Redirect::Inherit, error: error)
          raise Error.new("Error Target #{target.name} failed to run:\n#{error}") unless status.success?
        elsif raise Error.new("Error Target #{targets.first} not found.")
        end
      end
    end
  end
end
