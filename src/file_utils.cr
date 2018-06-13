module Shards::FileUtils
  def self.rm_rf_logging(path)
    return unless File.exists?(path) || File.symlink?(path)

    if Dir.exists?(path)
      command = "rm -rf #{escape path}"
      Shards.logger.debug command
      system command
    else
      Shards.logger.debug "rm #{escape path}"
      File.delete(path)
    end
  end

  def self.escape(path)
    "'#{path.gsub(/'/, "\\'")}'"
  end
end
