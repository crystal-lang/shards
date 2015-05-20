module Shards
  class GitResolver < Resolver
    def git_url
      dependency["git"]
    end
  end

  register_resolver :git, GitResolver
end
