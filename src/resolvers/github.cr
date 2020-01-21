require "./git"

module Shards
  class GithubResolver < GitResolver
    def self.key
      "github"
    end

    def git_url
      "https://github.com/#{dependency["github"]}.git"
    end
  end

  register_resolver GithubResolver
end
