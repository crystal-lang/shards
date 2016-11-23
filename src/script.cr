module Shards
  module Script
    class Error < Error
    end

    def self.run(path, command)
      Dir.cd(path) do
        output = IO::Memory.new
        status = Process.run("/bin/sh", input: IO::Memory.new(command), output: output, error: output)
        raise Error.new("Failed #{command}:\n#{output.to_s.rstrip}") unless status.success?
      end
    end
  end
end
