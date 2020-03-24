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

        raise Error.new("Error no targets defined") if targets.empty?

        if targets.size > 1
          if specific_target_requested
            raise Error.new("Error please specify only one target. If you meant to pass arguments you may use 'shards run target -- args'")
          else
            raise Error.new("Error please specify the target with 'shards run target'")
          end
        end

        if target = spec.targets.find { |t| t.name == targets.first }
          Commands::Build.run(path, targets, options)
          Shards.logger.info { "Executing: #{target.name} #{run_options.join(' ')}" }
          Process.exec(command: File.join(Shards.bin_path, target.name), args: run_options)
        else
          raise Error.new("Error target #{targets.first} was not found in #{SPEC_FILENAME}")
        end
      end
    end
  end
end
