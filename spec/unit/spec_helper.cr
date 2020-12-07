ENV["SHARDS_CACHE_PATH"] = ".shards"
ENV["SHARDS_INSTALL_PATH"] = File.expand_path(".lib", __DIR__)

require "spec"
require "../../src/config"
require "../../src/helpers"
require "../../src/logger"
require "../../src/resolvers/*"

require "../support/factories"
require "../support/requirement"

module Shards
  set_warning_log_level
end

Spec.before_each do
  clear_repositories
  Shards::Resolver.clear_resolver_cache
  Shards.info.reload
end

private def clear_repositories
  Shards::Helpers.rm_rf_children(tmp_path)
  Shards::Helpers.rm_rf(Shards.cache_path)
  Shards::Helpers.rm_rf(Shards.install_path)
end

def install_path(project, *path_names)
  File.join(Shards.install_path, project, *path_names)
end
