lib LibC
  fun symlink(old_path : UInt8*, new_path : UInt8*) : Int32
end

class File
  def self.symlink(old_path, new_path)
    ret = LibC.symlink(old_path, new_path)
    raise Errno.new("Error creating symlink from #{old_path} to #{new_path}") if ret == 0
    ret
  end
end

module Shards
  class PathResolver < Resolver
    def read_spec(version = nil)
      File.read(File.join(local_path, SPEC_FILENAME))
    end

    def available_versions
      [spec.version]
    end

    def local_path
      dependency["path"].to_s
    end

    def install(version = nil)
      Shards.logger.info "Using #{dependency.name} (#{local_path})"
      cleanup_install_directory
      File.symlink(local_path, install_path)
    end
  end

  register_resolver :path, PathResolver
end
