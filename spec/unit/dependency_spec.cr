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
