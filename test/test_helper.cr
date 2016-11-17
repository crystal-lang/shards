require "minitest/autorun"
require "../src/config"
require "../src/logger"
require "../src/manager"

Shards.cache_path = File.join(__DIR__, ".shards")
Shards.install_path = File.join(__DIR__, ".lib")

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
    run "rm -rf #{ Shards.cache_path }/*"
    run "rm -rf #{ Shards.install_path }/*"
  end

  def install_path(project, *path_names)
    File.join(Shards.install_path, project, *path_names)
  end
end
