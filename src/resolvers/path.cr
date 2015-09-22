require "./resolver"
#require "../core_ext/file"

module Shards
  class PathResolver < Resolver
    def self.key
      "path"
    end

    def read_spec(version = nil)
      path = File.join(local_path, SPEC_FILENAME)

      if File.exists?(path)
        File.read(path)
      else
        "name: #{dependency.name}\nversion: 0\n"
      end
    end

    def installed_spec
      return unless installed?

      path = File.join(local_path, SPEC_FILENAME)
      return Spec.from_file(path) if File.exists?(path)

      Spec.from_yaml("name: #{dependency.name}\nversion: 0\n")
    end

    def installed_commit_hash
    end

    def installed?
      File.symlink?(install_path)
    end

    def available_versions
      [spec.version]
    end

    def local_path
      dependency["path"].to_s
    end

    def install(version = nil)
      cleanup_install_directory
      Dir.mkdir_p(File.dirname(install_path))
      File.symlink(File.join(local_path, "src"), install_path)
    end
  end

  register_resolver PathResolver
end
