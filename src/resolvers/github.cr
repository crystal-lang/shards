module Shards
  class GithubResolver < GitResolver
    def git_url
      "https://github.com/#{dependency["github"]}.git"
    end
  end

  register_resolver :github, GithubResolver
end
