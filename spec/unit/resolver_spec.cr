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

    describe "#spec" do
      it "reports parse error location" do
        create_path_repository "foo", "1.2.3"
        create_file "foo", "shard.yml", "name: foo\nname: foo\n"

        resolver = Shards::PathResolver.new("foo", git_path("foo"))

        error = expect_raises(ParseError, %(Error in foo:shard.yml: duplicate attribute "name" at line 2, column 1)) do
          resolver.spec Shards::Version.new("1.2.3")
        end
        error.resolver.should eq resolver
      end
    end
  end
end
