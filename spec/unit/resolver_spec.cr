require "./spec_helper"

module Shards
  describe Resolver do
    it "find resolver" do
      Resolver.find_resolver("git", "test", "file:///tmp/test")
        .should eq(GitResolver.new("test", "file:///tmp/test"))
    end

    it "compares" do
      resolver = PathResolver.new("name", "/path")

      resolver.should eq(resolver)
      resolver.should eq(PathResolver.new("name", "/path"))
      resolver.should_not eq(PathResolver.new("name2", "/path"))
      resolver.should_not eq(PathResolver.new("name", "/path2"))
      resolver.should_not eq(GitResolver.new("name", "/path"))
    end
  end
end
