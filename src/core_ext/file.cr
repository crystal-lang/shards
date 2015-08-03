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
