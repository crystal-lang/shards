require "./info"

module Shards
  SPEC_FILENAME = "shard.yml"
  LOCK_FILENAME = "shard.lock"
  INSTALL_DIR   = ".crystal/shards"

  DEFAULT_COMMAND = "install"
  DEFAULT_VERSION = "0"

  VERSION_REFERENCE     = /^v?\d+[-.][-.a-zA-Z\d]+$/
  VERSION_TAG           = /^v(\d+[-.][-.a-zA-Z\d]+)$/
  VERSION_AT_GIT_COMMIT = /^(\d+[-.][-.a-zA-Z\d]+)\+git\.commit\.([0-9a-f]+)$/

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
      rescue File::Error
      end
    end

    raise Error.new("Failed to find or create cache directory")
  end

  def self.cache_path=(@@cache_path : String)
  end

  def self.install_path
    @@install_path ||= begin
      ENV.fetch("SHARDS_INSTALL_PATH") { File.join(Dir.current, INSTALL_DIR) }
    end
  end

  def self.install_path=(@@install_path : String)
  end

  def self.info
    @@info ||= Info.new
  end

  def self.warn_about_legacy_libs_path
    return if ENV["SHARDS_INSTALL_PATH"]?

    legacy_install_path = File.join(Dir.current, "lib")

    if File.exists?(legacy_install_path) && !File.exists?(install_path)
      Log.warn { "Shards now installs dependencies into the '.crystal/shards' directory. You may move or delete the legacy 'lib' directory." }
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
