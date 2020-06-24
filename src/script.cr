module Shards
  module Script
    class Error < Error
    end

    def self.run(path, command, script_name, dependency_name)
      Dir.cd(path) do
        output = IO::Memory.new
        status = Process.run("/bin/sh", env: Script.environment, input: IO::Memory.new(command), output: output, error: output)
        raise Error.new("Failed #{script_name} of #{dependency_name} on #{command}:\n#{output.to_s.rstrip}") unless status.success?
      end
    end

    @@environment : Process::Env = nil

    def self.environment : Process::Env
      @@environment ||=
        begin
          bin_path = File.tempname(".shards-env")
          Dir.mkdir(bin_path)
          at_exit do
            Dir.new(bin_path).each_child do |e|
              File.delete(File.join(bin_path, e))
            end
            Dir.delete bin_path
          end
          env_path = prepend_path(bin_path, ENV["PATH"]?)
          Log.debug { "shards script environment created at #{bin_path}. Updated PATH=#{env_path}" }

          add_executable bin_path, "shards", Process.executable_path
          add_executable bin_path, "crystal", Process.find_executable(Shards.crystal_bin)

          {"PATH" => env_path}
        rescue e
          Log.error(exception: e) { "Unable to create shards script environment" }

          {} of String => String
        end
    end

    private def self.add_executable(bin_path : String, name : String, original_path : String?)
      if original_path
        Log.debug { "Adding #{name}=#{original_path} to shards script environment" }
        File.symlink(original_path, File.join(bin_path, name))
      end
    end

    private def self.prepend_path(prefix : String, suffix : String?)
      suffix ? "#{prefix}:#{suffix}" : prefix
    end
  end
end
