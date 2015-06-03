module Shards
  SPEC_FILENAME = "shard.yml"

  CACHE_DIRECTORY = File.join(Dir.working_directory, ".shards")
  Dir.mkdir(CACHE_DIRECTORY) unless Dir.exists?(CACHE_DIRECTORY)

  INSTALL_PATH = File.join(Dir.working_directory, "libs")
  Dir.mkdir(INSTALL_PATH) unless Dir.exists?(INSTALL_PATH)

  DEFAULT_COMMAND = "install"
end

require "./logger"
require "./errors"
require "./version"
require "./cli"
