require "./spec"

module Shards
  abstract class Resolver
    getter :dependency

    def initialize(@dependency)
    end

    def spec(version = nil)
      Spec.new(read_spec(version))
    end

    abstract def read_spec(version = nil)
    abstract def available_versions
  end

  @@resolver_classes = {} of String => Resolver.class
  @@resolvers = {} of String => Resolver

  def self.register_resolver(name, resolver)
    @@resolver_classes[name.to_s] = resolver
  end

  def self.find_resolver(dependency)
    @@resolvers[dependency.name] ||= begin
      klass = get_resolver_class(dependency.keys)
      raise Error.new("can't resolve dependency #{dependency.name} (unsupported resolver)") unless klass
      klass.new(dependency)
    end
  end

  private def self.get_resolver_class(names)
    names.each do |name|
      if resolver = @@resolver_classes[name.to_s]
        return resolver
      end
    end

    nil
  end
end

require "./resolvers/git"
require "./resolvers/github"
require "./resolvers/bitbucket"
require "./resolvers/path"
