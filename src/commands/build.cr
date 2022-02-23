require "./command"

module Shards
  module Commands
    class Build < Command
      def run(targets, options)
        if spec.targets.empty?
          raise Error.new("Targets not defined in #{SPEC_FILENAME}")
        end

        unless Dir.exists?(Shards.bin_path)
          Log.debug { "mkdir #{Shards.bin_path}" }
          Dir.mkdir(Shards.bin_path)
        end

        if targets.empty?
          targets = spec.targets.map(&.name)
        end

        job_targets = Channel(Target).new(targets.size)
        done = Channel(Error?).new
        Shards.jobs.times do
          spawn do
            while target = job_targets.receive?
              begin
                build(target, options)
                done.send(nil)
              rescue ex : Error
                done.send(ex)
              end
            end
          end
        end

        targets.each do |name|
          if target = spec.targets.find { |t| t.name == name }
            job_targets.send(target)
          else
            raise Error.new("Error target #{name} was not found in #{SPEC_FILENAME}.")
          end
        end
        job_targets.close

        targets.size.times do
          ex = done.receive
          raise ex if ex
        end
      end

      private def build(target, options)
        Log.info { "Building: #{target.name}" }

        args = [
          "build",
          "-o", File.join(Shards.bin_path, target.name),
          target.main,
        ]
        unless Shards.colors?
          args << "--no-color"
        end
        if Shards::Log.level <= ::Log::Severity::Debug
          args << "--verbose"
        end
        options.each { |option| args << option }
        Log.debug { "#{Shards.crystal_bin} #{args.join(' ')}" }

        error = IO::Memory.new
        status = Process.run(Shards.crystal_bin, args: args, output: Process::Redirect::Inherit, error: error)
        if status.success?
          STDERR.puts error unless error.empty?
        else
          raise Error.new("Error target #{target.name} failed to compile:\n#{error}")
        end
      end
    end
  end
end
