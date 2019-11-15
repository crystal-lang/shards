require "./git"

module Shards
  class BitbucketResolver < GitResolver
    def self.key
      "bitbucket"
    end

    def git_url
      "https://bitbucket.org/#{dependency.url}.git"
    end
  end

  register_resolver BitbucketResolver
end
