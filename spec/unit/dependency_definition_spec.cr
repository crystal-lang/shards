require "./spec_helper"
require "../../src/dependency_definition"

private def expect_parses(value, resolver_key : String, source : String, requirement : Shards::Requirement)
  Shards::DependencyDefinition.parts_from_cli(value).should eq(Shards::DependencyDefinition::Parts.new(resolver_key: resolver_key, source: source, requirement: requirement))
end

module Shards
  describe DependencyDefinition do
    it ".parts_from_cli" do
      # GitHub short syntax
      expect_parses("github:foo/bar", "github", "foo/bar", Any)
      expect_parses("github:Foo/Bar@1.2.3", "github", "Foo/Bar", VersionReq.new("~> 1.2.3"))

      # GitHub urls
      expect_parses("https://github.com/foo/bar", "github", "foo/bar", Any)

      # GitHub urls from clone popup
      expect_parses("https://github.com/foo/bar.git", "github", "foo/bar", Any)
      expect_parses("git@github.com:foo/bar.git", "git", "git@github.com:foo/bar.git", Any)

      # GitLab short syntax
      expect_parses("gitlab:foo/bar", "gitlab", "foo/bar", Any)

      # GitLab urls
      expect_parses("https://gitlab.com/foo/bar", "gitlab", "foo/bar", Any)

      # GitLab urls from clone popup
      expect_parses("https://gitlab.com/foo/bar.git", "gitlab", "foo/bar", Any)
      expect_parses("git@gitlab.com:foo/bar.git", "git", "git@gitlab.com:foo/bar.git", requirement: Any)

      # Bitbucket short syntax
      expect_parses("bitbucket:foo/bar", "bitbucket", "foo/bar", Any)

      # bitbucket urls
      expect_parses("https://bitbucket.com/foo/bar", "bitbucket", "foo/bar", Any)

      # unknown https urls
      expect_raises Shards::Error, "Cannot determine resolver for HTTPS URI" do
        Shards::DependencyDefinition.parts_from_cli("https://example.com/foo/bar")
      end

      # Git convenient syntax since resolver matches scheme
      expect_parses("git://git.example.org/crystal-library.git", "git", "git://git.example.org/crystal-library.git", Any)
      expect_parses("git@example.org:foo/bar.git", "git", "git@example.org:foo/bar.git", Any)

      # Local paths
      local_absolute = "/an/absolute/path"
      local_relative = "an/relative/path"

      # Path short syntax
      expect_parses("../#{local_relative}", "path", "../#{local_relative}", Any)
      {% if flag?(:windows) %}
        expect_parses(".\\relative\\windows", "path", "./relative/windows", Any)
        expect_parses("..\\relative\\windows", "path", "../relative/windows", Any)
      {% else %}
        expect_parses("./#{local_relative}", "path", "./#{local_relative}", Any)
      {% end %}
      # Path file schema
      expect_raises Shards::Error, "Invalid file URI" do
        Shards::DependencyDefinition.parts_from_cli("file://#{local_relative}")
      end
      expect_parses("file:#{local_relative}", "path", local_relative, Any)
      expect_parses("file:#{local_absolute}", "path", local_absolute, Any)
      expect_parses("file://#{local_absolute}", "path", local_absolute, Any)
      # Path resolver syntax
      expect_parses("path:#{local_absolute}", "path", local_absolute, Any)
      expect_parses("path:#{local_relative}", "path", local_relative, Any)
      # Other resolvers short
      expect_parses("git:git://git.example.org/crystal-library.git", "git", "git://git.example.org/crystal-library.git", Any)
      expect_parses("git+https://example.org/foo/bar", "git", "https://example.org/foo/bar", Any)
      expect_parses("git:https://example.org/foo/bar", "git", "https://example.org/foo/bar", Any)
    end
  end
end
