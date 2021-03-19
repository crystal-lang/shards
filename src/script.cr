module Shards
  module Script
    class Error < Error
    end

    def self.run(path : String, command : String, script_name : String, dependency_name : String, skip : Bool) : Nil
      if !skip
        Log.info { "#{script_name.capitalize} of #{dependency_name}: #{command}" }
        self.run(path, command, script_name, dependency_name)
      else
        Log.info { "#{script_name.capitalize} of #{dependency_name}: #{command} (skipped)" }
      end
    end

    def self.run(path : String, command : String, script_name : String, dependency_name : String) : Nil
      Dir.cd(path) do
        output = IO::Memory.new
        status = Process.run(command, shell: true, output: output, error: output)
        raise Error.new("Failed #{script_name} of #{dependency_name} on #{command}:\n#{output.to_s.rstrip}") unless status.success?
      end
    end
  end
end
