require "./git"

module Shards
  class GitlabResolver < GitResolver
    def self.key
      "gitlab"
    end

    def git_url
      "https://gitlab.com/#{dependency["gitlab"]}.git"
    end
  end

  register_resolver GitlabResolver
end
