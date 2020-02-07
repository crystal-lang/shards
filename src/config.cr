module Shards
  SPEC_FILENAME = "shard.yml"
  LOCK_FILENAME = "shard.lock"

  DEFAULT_COMMAND = "install"
  DEFAULT_VERSION = "0"

  VERSION_REFERENCE     = /^v?\d+[-.][-.a-zA-Z\d]+$/
  VERSION_TAG           = /^v(\d+[-.][-.a-zA-Z\d]+)$/
  VERSION_AT_GIT_COMMIT = /\+git\.commit\.([0-9a-f]+)$/

  def self.cache_path
    @@cache_path ||= find_or_create_cache_path
  end

  private def self.find_or_create_cache_path
    candidates = [
      ENV["SHARDS_CACHE_PATH"]?,
      ENV["XDG_CACHE_HOME"]?.try { |cache| File.join(cache, "shards") },
      ENV["HOME"]?.try { |home| File.join(home, ".cache", "shards") },
      ENV["HOME"]?.try { |home| File.join(home, ".cache", ".shards") },
      File.join(Dir.current, ".shards"),
    ]

    candidates.each do |candidate|
      next unless candidate

      path = File.expand_path(candidate)
      return path if File.exists?(path)

      begin
        Dir.mkdir_p(path)
        return path
      rescue Errno
      end
    end

    raise Error.new("Failed to find or create cache directory")
  end

  def self.cache_path=(@@cache_path : String)
  end

  def self.install_path
    @@install_path ||= begin
      warn_about_legacy_libs_path
      ENV.fetch("SHARDS_INSTALL_PATH") { File.join(Dir.current, "lib") }
    end
  end

  def self.install_path=(@@install_path : String)
  end

  private def self.warn_about_legacy_libs_path
    # TODO: drop me in a future release

    legacy_install_path = if path = ENV["SHARDS_INSTALL_PATH"]?
                            File.join(File.dirname(path), "libs")
                          else
                            File.join(Dir.current, "libs")
                          end

    if File.exists?(legacy_install_path)
      Shards.logger.warn "Shards now installs dependencies into the 'lib' folder. You may delete the legacy 'libs' folder."
    end
  end

  def self.bin_path
    @@bin_path ||= ENV.fetch("SHARDS_BIN_PATH") { File.join(Dir.current, "bin") }
  end

  def self.bin_path=(@@bin_path : String)
  end

  class_property? production = false
  class_property? local = false
end
