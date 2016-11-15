require "./command"

module Shards
  module Commands
    class Build < Command
      def run
        # Return if 'crystal' command is not installed
        return unless has_crystal_command?

        @sub ||= "default"

        if @sub == "all"
          manager.spec.targets.each do |target|
            build target
          end
        else
          target = manager.spec.targets.find{ |t| t.name == @sub }
          raise Error.new("Target \'#{@sub}\' is not found") if target.nil?
          build target
        end
      end

      def build(target)
        Shards.logger.info "Building: #{target.name}"

        error = MemoryIO.new
        status = Process.run("/bin/sh", input: MemoryIO.new(target.cmd), output: nil, error: error)
        raise Error.new("#{error.to_s}") unless status.success?
      end

      def has_crystal_command?
        raise Error.new("\'crystal\' is not installed") unless system("which crystal > /dev/null 2>&1")
        true
      end
    end
  end
end
