module Shards::Helpers
  def self.rm_rf(path : String) : Nil
    # TODO: delete this and use https://github.com/crystal-lang/crystal/pull/9903
    if !File.symlink?(path) && Dir.exists?(path)
      Dir.each_child(path) do |entry|
        src = File.join(path, entry)
        rm_rf(src)
      end
      Dir.delete(path)
    else
      begin
        File.delete(path)
      rescue File::AccessDeniedError
        # To be able to delete read-only files (e.g. ones under .git/) on Windows.
        File.chmod(path, 0o666)
        File.delete(path)
      end
    end
  rescue File::Error
  end

  def self.rm_rf_children(dir : String) : Nil
    Dir.each_child(dir) do |child|
      rm_rf(File.join(dir, child))
    end
  end

  def self.exe(name)
    {% if flag?(:win32) %}
      name + ".exe"
    {% else %}
      name
    {% end %}
  end
end
