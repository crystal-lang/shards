module Shards
  SPEC_FILENAME = "shard.yml"

  CACHE_DIRECTORY = File.join(Dir.working_directory, ".shards")
  Dir.mkdir(CACHE_DIRECTORY) unless Dir.exists?(CACHE_DIRECTORY)

  INSTALL_PATH = File.join(Dir.working_directory, "libs")
  Dir.mkdir(INSTALL_PATH) unless Dir.exists?(INSTALL_PATH)
end

require "option_parser"
require "./logger"
require "./errors"
require "./spec"
require "./manager"

begin
  OptionParser.parse! do |opts|
    opts.banner = "shards [options]"

    opts.on("--no-colors", "") do
      Shards.colors = false
    end

    opts.on("-V", "--verbose", "") do
      Shards.logger.level = Logger::Severity::DEBUG
    end

    opts.on("-q", "--quiet", "") do
      Shards.logger.level = Logger::Severity::WARN
    end

    opts.on("-h", "--help", "") do
      puts opts
      exit
    end
  end

  spec = Shards::Spec.from_file(Dir.working_directory)
  manager = Shards::Manager.new(spec)
  manager.resolve
  manager.packages.each(&.install)

rescue ex : OptionParser::InvalidOption
  Shards.logger.fatal ex.message
  exit -1

rescue ex : Shards::Error
  Shards.logger.error ex.message
  exit -1
end
