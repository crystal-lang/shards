require "./git"

module Shards
  class BitbucketResolver < GitResolver
    def self.key
      "bitbucket"
    end

    def git_url
      "https://bitbucket.org/#{dependency["bitbucket"]}.git"
    end

    def normalize_origin(origin : String)
      origin.sub("git@bitbucket.org:", "https://bitbucket.org/")
    end
  end

  register_resolver BitbucketResolver
end
