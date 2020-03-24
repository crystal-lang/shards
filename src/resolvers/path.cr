require "./resolver"

module Shards
  class PathResolver < Resolver
    def self.key
      "path"
    end

    def read_spec(version = nil)
      spec_path = File.join(local_path, SPEC_FILENAME)

      if File.exists?(spec_path)
        File.read(spec_path)
      else
        raise Error.new("Missing #{SPEC_FILENAME.inspect} for #{dependency.name.inspect}")
      end
    end

    def dependency_path
      @dependency.path
    end

    def spec?(version)
      spec_path = File.join(local_path, SPEC_FILENAME)

      if File.exists?(spec_path)
        Spec.from_yaml(File.read(spec_path))
        # TODO: fail if the spec isn't the expected version!
      end
    end

    def installed_spec
      Spec.from_yaml(read_spec) if installed?
    end

    def installed_commit_hash
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

    def available_versions
      [spec.version]
    end

    def local_path
      dependency["path"].to_s
    end

    private def expanded_local_path
      File.expand_path(local_path).tap do |path|
        raise Error.new("Failed no such path: #{path}") unless Dir.exists?(path)
      end
    end

    def install(version = nil)
      path = expanded_local_path

      cleanup_install_directory
      Dir.mkdir_p(File.dirname(install_path))
      File.symlink(path, install_path)
    end
  end

  register_resolver PathResolver
end
