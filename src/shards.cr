module Shards
  SPEC_FILENAME = "shard.yml"
  CACHE_DIRECTORY = File.join(Dir.working_directory, ".shards")

  unless Dir.exists?(CACHE_DIRECTORY)
    Dir.mkdir(CACHE_DIRECTORY)
  end
end

require "./logger"
require "./errors"
require "./spec"
require "./manager"

begin
  spec = Shards::Spec.from_file(Dir.working_directory)
  manager = Shards::Manager.new(spec)
  manager.resolve

  # TODO: install packages into the libs/ folder
  manager.packages.each do |package|
    p [package.name, package.version]
  end
rescue ex : Shards::Error
  Shards.logger.error ex.message
  exit -1
end
