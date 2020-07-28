require "./info"

module Shards
  SPEC_FILENAME     = "shard.yml"
  LOCK_FILENAME     = "shard.lock"
  OVERRIDE_FILENAME = "shard.override.yml"
  INSTALL_DIR       = "lib"

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

  def self.bin_path
    @@bin_path ||= ENV.fetch("SHARDS_BIN_PATH") { File.join(Dir.current, "bin") }
  end

  def self.bin_path=(@@bin_path : String)
  end

  def self.global_override_filename
    ENV["SHARDS_OVERRIDE"]?.try { |p| File.expand_path(p) }
  end

  def self.crystal_version
    @@crystal_version ||= without_prerelease(ENV["CRYSTAL_VERSION"]? || begin
      output = IO::Memory.new
      error = IO::Memory.new
      status = begin
        Process.run("crystal", {"env", "CRYSTAL_VERSION"}, output: output, error: error)
      rescue e
        raise Error.new("Could not execute 'crystal': #{e.message}")
      end
      raise Error.new("Error executing crystal:\n#{error}") unless status.success?
      output.to_s.strip
    end)
  end

  def self.crystal_version(@@crystal_version : String)
  end

  private def self.without_prerelease(version)
    if version =~ /^(\d+)\.(\d+)\.(\d+)([^\w]\w+)$/
      "#{$1}.#{$2}.#{$3}"
    else
      version
    end
  end

  class_property? production = false
  class_property? local = false
  class_property? ignore_crystal_version = false
end
