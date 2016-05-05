module Shards
  SPEC_FILENAME = "shard.yml"
  LOCK_FILENAME = "shard.lock"

  DEFAULT_COMMAND = "install"
  DEFAULT_VERSION = "0"

  @@production = false

  def self.production?
    @@production
  end

  def self.production=(@@production)
  end

  def self.cache_directory
    @@cache_directory ||= ENV["SHARDS_CACHE_PATH"]? || File.join(Dir.current, ".shards")
  end

  def self.install_path
    @@install_path ||= ENV["SHARDS_INSTALL_PATH"]? || File.join(Dir.current, "libs")
  end
end
