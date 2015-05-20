module Shards
  class BitbucketResolver < GitResolver
    def git_url
      "https://bitbucket.org/#{dependency["bitbucket"]}.git"
    end
  end

  register_resolver :bitbucket, BitbucketResolver
end
