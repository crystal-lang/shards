require "./resolver"

module Shards
  class PathResolver < Resolver
    def self.key
      "path"
    end

    def read_spec(version = nil) : String?
      spec_path = File.join(expanded_local_path, SPEC_FILENAME)

      if File.exists?(spec_path)
        File.read(spec_path)
      else
        raise Error.new("Missing #{SPEC_FILENAME.inspect} for #{name.inspect} at #{File.expand_path(local_path).inspect}")
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
      File.expand_path(local_path, home: true).tap do |path|
        raise Error.new("Failed no such path: #{path}") unless Dir.exists?(path)
      end
    end

    def install_sources(version, install_path)
      path = expanded_local_path

      install_dir = File.dirname(install_path)
      Dir.mkdir_p(install_dir)
      # The link is created from its own directory so that a relative target
      # is resolved against it on Windows when picking the directory flag.
      Dir.cd(install_dir) do
        File.symlink(symlink_target(path, install_dir), File.basename(install_path))
      end
    end

    # A relative path reference is linked relatively so the link keeps working
    # when the project is moved or shared between systems.
    private def symlink_target(path, install_dir)
      return path if Path[local_path].absolute? || local_path.starts_with?("~")

      Path[path].relative_to(File.expand_path(install_dir)).to_s
    end

    def report_version(version : Version) : String
      "#{version.value} at #{source}"
    end

    register_resolver "path", PathResolver
  end
end
