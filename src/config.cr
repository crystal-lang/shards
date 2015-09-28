module Shards
  SPEC_FILENAME = "shard.yml"
  LOCK_FILENAME = "shard.lock"

  CACHE_DIRECTORY = ENV["SHARDS_CACHE_PATH"]? || File.join(Dir.working_directory, ".shards")
  Dir.mkdir_p(CACHE_DIRECTORY) unless Dir.exists?(CACHE_DIRECTORY)

  INSTALL_PATH = ENV["SHARDS_INSTALL_PATH"]? || File.join(Dir.working_directory, "libs")
  Dir.mkdir_p(INSTALL_PATH) unless Dir.exists?(INSTALL_PATH)

  DEFAULT_COMMAND = "install"
  DEFAULT_VERSION = "0"

  @@production = false

  def self.production?
    @@production
  end

  def self.production=(@@production)
  end
end
