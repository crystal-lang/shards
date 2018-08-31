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
        "name: #{dependency.name}\nversion: #{DEFAULT_VERSION}\n"
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
