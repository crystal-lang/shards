require "./git"

module Shards
  class GithubResolver < GitResolver
    def self.key
      "github"
    end

    def git_url
      "https://github.com/#{dependency["github"]}.git"
    end

    def normalize_origin(origin : String)
      origin.sub("git@github.com:", "https://github.com/")
    end
  end

  register_resolver GithubResolver
end
