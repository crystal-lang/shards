require "./spec_helper"
require "../../src/override"

module Shards
  describe Override do
    it "parses" do
      override = Override.from_yaml <<-YAML
      dependencies:
        repo:
          github: user/repo
          version: 1.2.3
        example:
          git: https://example.com/example-crystal.git
          branch: master
        local:
          path: /var/clones/local
      YAML

      override.dependencies.size.should eq(3)

      override.dependencies[0].name.should eq("repo")
      override.dependencies[0].resolver.should eq(GitResolver.new("repo", "https://github.com/user/repo.git"))
      override.dependencies[0].resolver.is_override.should eq(true)
      override.dependencies[0].requirement.should eq(version_req "1.2.3")

      override.dependencies[1].name.should eq("example")
      override.dependencies[1].resolver.should eq(GitResolver.new("example", "https://example.com/example-crystal.git"))
      override.dependencies[1].resolver.is_override.should eq(true)
      override.dependencies[1].requirement.should eq(branch "master")

      override.dependencies[2].name.should eq("local")
      override.dependencies[2].resolver.should eq(PathResolver.new("local", "/var/clones/local"))
      override.dependencies[2].resolver.is_override.should eq(true)
      override.dependencies[2].requirement.should eq(Any)
    end

    it "fails dependency with duplicate resolver" do
      expect_raises Shards::ParseError, %(Duplicate resolver mapping for dependency "foo" at line 4, column 5) do
        Override.from_yaml <<-YAML
          dependencies:
            foo:
              github: user/repo
              gitlab: user/repo
          YAML
      end
    end

    it "fails dependency with missing resolver" do
      expect_raises Shards::ParseError, %(Missing resolver for dependency "foo" at line 2, column 3) do
        Override.from_yaml <<-YAML
          dependencies:
            foo:
              branch: master
          YAML
      end
    end

    it "accepts dependency with extra attributes" do
      override = Override.from_yaml <<-YAML
        dependencies:
          foo:
            github: user/repo
            extra: foobar
        YAML
      dep = Dependency.new("foo", GitResolver.new("foo", "https://github.com/user/repo.git"), Any)
      override.dependencies[0].should eq dep
    end

    it "skips unknown attributes" do
      override = Override.from_yaml("\nanme: test\ncustom:\n  test: more\nname: test\nversion: 1\n")
      override.dependencies.should be_empty
    end

    it "raises on unknown attributes if validating" do
      expect_raises(ParseError, "unknown attribute: deps") { Override.from_yaml("deps:", validate: true) }
    end

    it "fails to parse dependencies" do
      str = <<-YAML
      dependencies:
        github: spalger/crystal-mime
        branch: master
      YAML
      expect_raises(ParseError) { Override.from_yaml(str) }
    end

    it "errors on duplicate attributes" do
      expect_raises(ParseError, %(duplicate attribute "dependencies")) do
        Override.from_yaml <<-YAML
          dependencies:
            bar:
              github: foo/bar
          dependencies:
            baz:
              github: foo/baz
        YAML
      end
    end

    it "parses empty dependencies" do
      override = Override.from_yaml("dependencies: {}\n")
      override.dependencies.should be_empty
    end
  end
end
