module FileUtils
  def self.rm_rf(path)
    return unless File.exists?(path)

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
