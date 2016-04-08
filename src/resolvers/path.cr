require "./resolver"
#require "../core_ext/file"

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
        projectfile_path = File.join(local_path, "Projectfile")

        if File.exists?(projectfile_path)
          contents = File.read(projectfile_path)
          dependencies = parse_legacy_projectfile_to_yaml(contents)
        end

        "name: #{dependency.name}\nversion: #{DEFAULT_VERSION}\n#{dependencies}"
      end
    end

    def installed_spec
      Spec.from_yaml(read_spec) if installed?
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

      src_path = File.expand_path(File.join(local_path, "src"))
      raise Error.new("Failed no such path: #{local_path}") unless Dir.exists?(src_path)

      File.symlink(src_path, install_path)
    end
  end

  register_resolver PathResolver
end
