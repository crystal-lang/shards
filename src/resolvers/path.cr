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
      spec = Spec.from_yaml(read_spec(version))
      spec.resolver = self
      spec
    end

    def installed?
      File.symlink?(install_path) && check_install_path_target
    end

    private def check_install_path_target
      {% if compare_versions(Crystal::VERSION, "0.34.0-0") > 0 %}
        begin
          real_install_path = File.real_path(install_path)
        rescue File::NotFoundError
          return false
        end
        real_install_path == expanded_local_path
      {% else %}
        begin
          real_install_path = File.real_path(install_path)
        rescue errno : Errno
          if errno.errno == Errno::ENOENT
            return false
          else
            raise errno
          end
        end
        real_install_path == expanded_local_path
      {% end %}
    end

    def available_releases : Array(Version)
      [spec(nil).version]
    end

    def latest_version_for_ref(ref : Ref?) : Version?
    end

    def local_path
      source
    end

    private def expanded_local_path
      File.expand_path(local_path).tap do |path|
        raise Error.new("Failed no such path: #{path}") unless Dir.exists?(path)
      end
    end

    def install_sources(version)
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
