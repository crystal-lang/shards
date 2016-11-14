require "./command"

module Shards
  module Commands
    class Build < Command
      def run
        # Return if 'crystal' command is not installed
        return unless crystal_is_installed?

        name = @sub.nil? ? "default" : @sub

        if name == "all"
          Shards.logger.info "Build all targets"
          manager.spec.targets.each do |target|
            build target
          end
        else
          target = manager.spec.targets.find{ |t| t.name == name }
          raise Error.new("Target \'#{name}\' is not found") if target.nil?
          build target
        end
      end

      def build(target)
        Shards.logger.info "Target: #{target.name}"
        Shards.logger.info "   cmd: #{target.cmd}"
        # git.cr L232
      end

      def crystal_is_installed?
        raise Error.new("\'crystal\' is not installed") unless system("which crystal > /dev/null 2>&1")
        true
      end
    end
  end
end
