require "../lock"
require "../manager"
require "../spec"

module Shards
  abstract class Command
    getter path : String
    getter spec_path : String
    getter lockfile_path : String

    @spec : Spec?
    @locks : Array(Dependency)?

    def initialize(path)
      if File.directory?(path)
        @path = path
        @spec_path = File.join(path, SPEC_FILENAME)
      else
        @path = File.dirname(path)
        @spec_path = path
      end
      @lockfile_path = File.join(@path, LOCK_FILENAME)
    end

    abstract def run(*args)

    def self.run(path, *args)
      new(path).run(*args)
    end

    def spec
      @spec ||= if File.exists?(spec_path)
                  Spec.from_file(spec_path)
                else
                  raise Error.new("Missing #{ spec_filename }. Please run 'shards init'")
                end
    end

    def spec_filename
      File.basename(spec_path)
    end

    def manager
      @manager ||= Manager.new(spec)
    end

    def locks
      @locks ||= if lockfile?
                   Lock.from_file(lockfile_path)
                 else
                   raise Error.new("Missing #{ LOCK_FILENAME }. Please run 'shards install'")
                 end
    end

    def lockfile?
      File.exists?(lockfile_path)
    end
  end
end
