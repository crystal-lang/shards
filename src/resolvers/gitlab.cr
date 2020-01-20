require "./git"

module Shards
  class GitlabResolver < GitResolver
    def self.key
      "gitlab"
    end

    def git_url
      "https://gitlab.com/#{dependency["gitlab"]}.git"
    end

    def normalize_origin(origin : String)
      origin.sub("git@gitlab.com:", "https://gitlab.com/")
    end
  end

  register_resolver GitlabResolver
end
