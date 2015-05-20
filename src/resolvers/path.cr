module Shards
  class PathResolver < Resolver
  end

  register_resolver :path, GitResolver
end
