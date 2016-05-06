module Shards
  SPEC_FILENAME = "shard.yml"
  LOCK_FILENAME = "shard.lock"

  DEFAULT_COMMAND = "install"
  DEFAULT_VERSION = "0"

  def self.cache_path
    @@cache_path ||= ENV.fetch("SHARDS_CACHE_PATH") { File.join(Dir.current, ".shards") }
  end

  def self.cache_path=(@@cache_path : String)
  end

  def self.install_path
    @@install_path ||= ENV.fetch("SHARDS_INSTALL_PATH") { File.join(Dir.current, "libs") }
  end

  def self.install_path=(@@install_path : String)
  end

  @@production = false

  def self.production?
    @@production
  end

  def self.production=(@@production)
  end
end
