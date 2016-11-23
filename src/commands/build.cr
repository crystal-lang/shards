require "./command"

module Shards
  module Commands
    class Build < Command
      def run(targets, options)
        unless Dir.exists?(Shards.bin_path)
          Shards.logger.debug "mkdir #{Shards.bin_path}"
          Dir.mkdir(Shards.bin_path)
        end

        if targets.empty?
          targets = manager.spec.targets.map(&.name)
        end

        targets.each do |name|
          if target = spec.targets.find { |t| t.name == name }
            build(target, options)
          else
            raise Error.new("Error target #{name} was not found in #{SPEC_FILENAME}.")
          end
        end
      end

      private def build(target, options)
        Shards.logger.info "Building: #{target.name}"

        args = [
          "build",
          "-o", File.join(Shards.bin_path, target.name),
          target.main,
        ]
        options.each { |option| args << option }
        Shards.logger.debug "crystal #{args.join(' ')}"

        error = IO::Memory.new
        status = Process.run("crystal", args: args, output: error, error: error)
        raise Error.new("Error target #{target.name} failed to compile:\n#{error}") unless status.success?
      end
    end
  end
end
