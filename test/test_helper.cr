require "minitest/autorun"

ENV["SHARDS_CACHE_PATH"] = File.expand_path("../.shards", __FILE__)
ENV["SHARDS_INSTALL_PATH"] = File.expand_path("../.libs", __FILE__)

require "../src/config"
require "../src/logger"
require "../src/manager"

require "./support/factories"
require "./support/mock_resolver"

module Shards
  logger.level = Logger::Severity::WARN
end

class Minitest::Test
  def before_setup
    clear_repositories
    super
  end

  def clear_repositories
    run "rm -rf #{ tmp_path }/*"
    run "rm -rf #{ Shards::CACHE_DIRECTORY }/*"
    run "rm -rf #{ Shards::INSTALL_PATH }/*"
  end

  def install_path(project, *path_names)
    File.join(Shards::INSTALL_PATH, project, *path_names)
  end
end
