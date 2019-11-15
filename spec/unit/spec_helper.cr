ENV["SHARDS_CACHE_PATH"] = ".shards"
ENV["SHARDS_INSTALL_PATH"] = File.expand_path(".lib", __DIR__)

require "spec"
require "../../src/config"
require "../../src/logger"
require "../../src/resolvers/*"

require "../support/factories"

module Shards
  set_warning_log_level
end

Spec.before_each do
  clear_repositories
end

private def clear_repositories
  run "rm -rf #{tmp_path}/*"
  run "rm -rf #{Shards.cache_path}/*"
  run "rm -rf #{Shards.install_path}/*"
end

def install_path(project, *path_names)
  File.join(Shards.install_path, project, *path_names)
end
