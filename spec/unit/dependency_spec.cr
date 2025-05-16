require "./spec_helper"

module Shards
  describe Dependency do
    it "parse for path" do
      dep = parse_dependency({foo: {path: "/foo"}})
      dep.name.should eq("foo")
      dep.resolver.is_a?(PathResolver).should be_true
      dep.resolver.source.should eq("/foo")
      dep.requirement.should eq(Any)
    end

    it "parse for git" do
      dep = parse_dependency({foo: {git: "/foo"}})
      dep.name.should eq("foo")
      dep.resolver.is_a?(GitResolver).should be_true
      dep.resolver.source.should eq("/foo")
      dep.requirement.should eq(Any)
    end

    it "parse for git with version requirement" do
      dep = parse_dependency({foo: {git: "/foo", version: "~> 1.2"}})
      dep.name.should eq("foo")
      dep.resolver.is_a?(GitResolver).should be_true
      dep.resolver.source.should eq("/foo")
      dep.requirement.should eq(VersionReq.new("~> 1.2"))
    end

    it "parse for git with branch requirement" do
      dep = parse_dependency({foo: {git: "/foo", branch: "test"}})
      dep.name.should eq("foo")
      dep.resolver.is_a?(GitResolver).should be_true
      dep.resolver.source.should eq("/foo")
      dep.requirement.should eq(GitBranchRef.new("test"))
    end

    it "parse for git with tag requirement" do
      dep = parse_dependency({foo: {git: "/foo", tag: "test"}})
      dep.name.should eq("foo")
      dep.resolver.is_a?(GitResolver).should be_true
      dep.resolver.source.should eq("/foo")
      dep.requirement.should eq(GitTagRef.new("test"))
    end

    it "parse for git with commit requirement" do
      dep = parse_dependency({foo: {git: "/foo", commit: "7e2e840"}})
      dep.name.should eq("foo")
      dep.resolver.is_a?(GitResolver).should be_true
      dep.resolver.source.should eq("/foo")
      dep.requirement.should eq(GitCommitRef.new("7e2e840"))
    end

    it "parse for github" do
      dep = parse_dependency({foo: {github: "foo/bar"}})
      dep.name.should eq("foo")
      dep.resolver.is_a?(GitResolver).should be_true
      dep.resolver.source.should eq("https://github.com/foo/bar.git")
    end

    it "allow extra arguments" do
      dep = parse_dependency({foo: {path: "/foo", branch: "master"}})
      dep.name.should eq("foo")
      dep.resolver.is_a?(PathResolver).should be_true
      dep.requirement.should eq(Any)
    end

    it "format with to_s" do
      parse_dependency({foo: {git: ""}}).to_s.should eq("foo (*)")
      parse_dependency({foo: {git: "", version: "~> 1.0"}}).to_s.should eq("foo (~> 1.0)")
      parse_dependency({foo: {git: "", branch: "feature"}}).to_s.should eq("foo (branch feature)")
      parse_dependency({foo: {git: "", tag: "rc-1.0"}}).to_s.should eq("foo (tag rc-1.0)")
      parse_dependency({foo: {git: "", commit: "4478d8afe8c728f44b47d3582a270423cd7fc07d"}}).to_s.should eq("foo (commit 4478d8a)")
    end

    it ".parts_from_cli" do
      # GitHub short syntax
      Dependency.parts_from_cli("github:foo/bar").should eq({resolver_key: "github", source: "foo/bar", requirement: Any})
      Dependency.parts_from_cli("github:Foo/Bar@1.2.3").should eq({resolver_key: "github", source: "Foo/Bar", requirement: VersionReq.new("~> 1.2.3")})

      # GitHub urls
      Dependency.parts_from_cli("https://github.com/foo/bar").should eq({resolver_key: "github", source: "foo/bar", requirement: Any})
      Dependency.parts_from_cli("https://github.com/Foo/Bar/commit/000000").should eq({resolver_key: "github", source: "Foo/Bar", requirement: GitCommitRef.new("000000")})
      Dependency.parts_from_cli("https://github.com/Foo/Bar/tree/v1.2.3").should eq({resolver_key: "github", source: "Foo/Bar", requirement: GitTagRef.new("v1.2.3")})
      Dependency.parts_from_cli("https://github.com/Foo/Bar/tree/some/branch").should eq({resolver_key: "github", source: "Foo/Bar", requirement: GitBranchRef.new("some/branch")})

      # GitLab short syntax
      Dependency.parts_from_cli("gitlab:foo/bar").should eq({resolver_key: "gitlab", source: "foo/bar", requirement: Any})

      # GitLab urls
      Dependency.parts_from_cli("https://gitlab.com/foo/bar").should eq({resolver_key: "gitlab", source: "foo/bar", requirement: Any})

      # Bitbucket short syntax
      Dependency.parts_from_cli("bitbucket:foo/bar").should eq({resolver_key: "bitbucket", source: "foo/bar", requirement: Any})

      # bitbucket urls
      Dependency.parts_from_cli("https://bitbucket.com/foo/bar").should eq({resolver_key: "bitbucket", source: "foo/bar", requirement: Any})

      # Git convenient syntax since resolver matches scheme
      Dependency.parts_from_cli("git://git.example.org/crystal-library.git").should eq({resolver_key: "git", source: "git://git.example.org/crystal-library.git", requirement: Any})

      # Local paths
      local_absolute = File.join(tmp_path, "local")
      local_relative = File.join("spec", ".repositories", "local") # rel_path is relative to integration spec
      Dir.mkdir_p(local_absolute)

      # Path short syntax
      Dependency.parts_from_cli(local_absolute).should eq({resolver_key: "path", source: local_absolute, requirement: Any})
      Dependency.parts_from_cli(local_relative).should eq({resolver_key: "path", source: local_relative, requirement: Any})

      # Path resolver syntax
      Dependency.parts_from_cli("path:#{local_absolute}").should eq({resolver_key: "path", source: local_absolute, requirement: Any})
      Dependency.parts_from_cli("path:#{local_relative}").should eq({resolver_key: "path", source: local_relative, requirement: Any})

      # Other resolvers short
      Dependency.parts_from_cli("git:git://git.example.org/crystal-library.git").should eq({resolver_key: "git", source: "git://git.example.org/crystal-library.git", requirement: Any})
    end
  end
end

private def parse_dependency(dep)
  pull = YAML::PullParser.new(dep.to_yaml)
  pull.read_stream do
    pull.read_document do
      pull.read_mapping do
        Shards::Dependency.from_yaml(pull)
      end
    end
  end
end
