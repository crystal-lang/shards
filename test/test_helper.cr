require "minitest/autorun"

require "../src/config"
require "../src/logger"
require "../src/resolvers"
require "./support/factories"

module Shards
  logger.level = Logger::Severity::WARN

  class Resolver
    protected def install_path
      File.join(File.expand_path("../tmp/libs", __FILE__), dependency.name)
    end
  end
end
