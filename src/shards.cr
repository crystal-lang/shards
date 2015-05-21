module Shards
  SPEC_FILENAME = "shard.yml"

  CACHE_DIRECTORY = File.join(Dir.working_directory, ".shards")
  Dir.mkdir(CACHE_DIRECTORY) unless Dir.exists?(CACHE_DIRECTORY)

  INSTALL_PATH = File.join(Dir.working_directory, "libs")
  Dir.mkdir(INSTALL_PATH) unless Dir.exists?(INSTALL_PATH)
end

require "./logger"
require "./errors"
require "./spec"
require "./manager"

begin
  spec = Shards::Spec.from_file(Dir.working_directory)
  manager = Shards::Manager.new(spec)
  manager.resolve
  manager.packages.each(&.install)
rescue ex : Shards::Error
  Shards.logger.error ex.message
  exit -1
end
