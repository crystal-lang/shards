module Shards
  class Resolver
    getter :dependency

    def initialize(@dependency)
    end
  end

  @@resolvers = {} of String => Resolver.class

  def self.register_resolver(name, resolver)
    @@resolvers[name.to_s] = resolver
  end

  def self.find_resolver(names)
    names.each do |name|
      if resolver = @@resolvers[name.to_s]
        return resolver
      end
    end

    nil
  end
end

require "./resolvers/git"
require "./resolvers/github"
require "./resolvers/bitbucket"
