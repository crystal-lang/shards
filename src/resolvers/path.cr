lib LibC
  fun symlink(old_path : UInt8*, new_path : UInt8*) : Int32
end

class File
  def self.symlink(old_path, new_path)
    ret = LibC.symlink(old_path, new_path)
    raise Errno.new("Error creating symlink from #{old_path} to #{new_path}") if ret != 0
    ret
  end
end

module Shards
  class PathResolver < Resolver
    def read_spec(version = nil)
      path = File.join(local_path, SPEC_FILENAME)

      if File.exists?(path)
        File.read(path)
      else
        "name: #{dependency.name}\nversion: 0\n"
      end
    end

    def spec(version = nil)
      if version == :installed
        path = File.join(local_path, SPEC_FILENAME)
        return Spec.from_file(path) if File.exists?(path)
      end

      super
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

  register_resolver :path, PathResolver
end
