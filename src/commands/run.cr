require "./command"

module Shards
  module Commands
    class Run < Command
      def run(targets, options, run_options)
        if spec.targets.empty?
          raise Error.new("Targets not defined in #{SPEC_FILENAME}")
        end

        # when more than one target was specified
        if targets.size > 1
          raise Error.new("Error please specify only one target. If you meant to pass arguments you may use 'shards run target -- args'")
        end

        # when no target was specified
        if targets.empty?
          if spec.targets.size > 1
            raise Error.new("Error please specify the target with 'shards run target'")
          else
            name = spec.targets.first.name
          end
        else
          name = targets.first
        end

        if target = spec.targets.find { |t| t.name == name }
          Commands::Build.run(path, [target.name], options)

          Log.info { "Executing: #{target.name} #{run_options.join(' ')}" }

          {% if flag?(:win32) %}
            # FIXME: Process.exec doesn't work as expected on Windows, we need to run
            # as a child process and report the exit code afterwards. https://github.com/crystal-lang/crystal/issues/14422#issuecomment-3204803933
            status = Process.run(File.join(Shards.bin_path, target.name), args: run_options, input: Process::Redirect::Inherit, output: Process::Redirect::Inherit, error: Process::Redirect::Inherit)
            exit status.exit_code
          {% else %}
            # FIXME: The explicit close is necessary to flush the last log message
            # before `exec`. https://github.com/crystal-lang/crystal/issues/14422#issuecomment-3204803933
            ::Log.builder.close

            Process.exec(File.join(Shards.bin_path, target.name), args: run_options)
          {% end %}
        else
          raise Error.new("Error target #{name} was not found in #{SPEC_FILENAME}")
        end
      end
    end
  end
end
