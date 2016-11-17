require "./command"

module Shards
  module Commands
    class Build < Command

      @@args = [] of String

      # command line arguments
      @targets = [] of String
      @options = [] of String

      def run
        # Install dependencies before the build
        Install.run(@path)
        # Parse to find targets and options
        parse_args
        # mkdir bin
        mkdir_bin
        if @targets.empty?
          raise Error.new("Error: No target found in shard.yml") if manager.spec.targets.nil?
          manager.spec.targets.each do |target|
            build target
          end
        else
          @targets.each do |name|
            target = manager.spec.targets.find{ |t| t.name == name }
            raise Error.new("Error: target \'#{name}\' is not found") if target.nil?
            build target
          end
        end
      end

      def parse_args
        is_option? = false
        @@args.each do |arg|
          is_option? = true if arg.starts_with?('-')
          if is_option?
            @options.push(arg)
          else
            @targets.push(arg)
          end
        end
      end

      def mkdir_bin
        bin_path = File.join(@path, "bin")
        Dir.mkdir bin_path unless Dir.exists?(bin_path)
      end

      def build(target)
        Shards.logger.info "Building: #{target.name}"

        args = ["build", target.main] + @options
        unless @options.includes?("-o")
          args.push("-o")
          args.push(File.join("bin", target.name))
        end

        error = MemoryIO.new
        status = Process.run("crystal",
                             args: args,
                             output: nil, error: error)
        raise Error.new("#{error.to_s}") unless status.success?
      end

      def self.set_args(args : Array(String))
        @@args = args
      end
    end
  end
end
