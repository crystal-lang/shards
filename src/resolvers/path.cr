require "./resolver"

module Shards
  class PathResolver < Resolver
    def self.key
      "path"
    end

    def read_spec(version = nil) : String?
      spec_path = File.join(local_path, SPEC_FILENAME)

      if File.exists?(spec_path)
        File.read(spec_path)
      else
        raise Error.new("Missing #{SPEC_FILENAME.inspect} for #{name.inspect}")
      end
    end

    def spec(version = nil)
      load_spec(version) || raise Error.new("Can't read spec for #{name.inspect}")
    end

    def available_releases : Array(Version)
      [spec(nil).version]
    end

    def local_path
      source
    end

    private def expanded_local_path
      File.expand_path(local_path).tap do |path|
        raise Error.new("Failed no such path: #{path}") unless Dir.exists?(path)
      end
    end

    def install_sources(version, install_path)
      path = expanded_local_path

      Dir.mkdir_p(File.dirname(install_path))
      File.symlink(path, install_path)
    end

    def report_version(version : Version) : String
      "#{version.value} at #{source}"
    end

    register_resolver "path", PathResolver
  end
end
