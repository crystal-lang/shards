module Shards
  module Script
    def self.run(path, command)
      Dir.chdir(path) do
        status = Process.run("/bin/sh", input: command)
        raise Error.new("#{name} script failed: #{command}") unless status.success?
      end
    end
  end
end
