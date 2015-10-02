module Shards
  SPEC_FILENAME = "shard.yml"
  LOCK_FILENAME = "shard.lock"

  CACHE_DIRECTORY = ENV["SHARDS_CACHE_PATH"]? || File.join(Dir.working_directory, ".shards")
  INSTALL_PATH = ENV["SHARDS_INSTALL_PATH"]? || File.join(Dir.working_directory, "libs")

  DEFAULT_COMMAND = "install"
  DEFAULT_VERSION = "0"

  @@production = false

  def self.production?
    @@production
  end

  def self.production=(@@production)
  end
end
