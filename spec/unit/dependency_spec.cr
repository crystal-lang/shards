require "./spec_helper"

module Shards
  describe Dependency do
    it "parse for path" do
      parse_dependency({foo: {path: "/foo"}}) do |dep|
        dep.name.should eq("foo")
        dep.resolver.is_a?(PathResolver).should be_true
        dep.resolver.source.should eq("/foo")
        dep.requirement.should eq(Any)
      end
    end

    it "parse for git" do
      parse_dependency({foo: {git: "/foo"}}) do |dep|
        dep.name.should eq("foo")
        dep.resolver.is_a?(GitResolver).should be_true
        dep.resolver.source.should eq("/foo")
        dep.requirement.should eq(Any)
      end
    end

    it "parse for git with version requirement" do
      parse_dependency({foo: {git: "/foo", version: "~> 1.2"}}) do |dep|
        dep.name.should eq("foo")
        dep.resolver.is_a?(GitResolver).should be_true
        dep.resolver.source.should eq("/foo")
        dep.requirement.should eq(VersionReq.new("~> 1.2"))
      end
    end

    it "parse for git with branch requirement" do
      parse_dependency({foo: {git: "/foo", branch: "test"}}) do |dep|
        dep.name.should eq("foo")
        dep.resolver.is_a?(GitResolver).should be_true
        dep.resolver.source.should eq("/foo")
        dep.requirement.should eq(GitBranchRef.new("test"))
      end
    end

    it "parse for git with tag requirement" do
      parse_dependency({foo: {git: "/foo", tag: "test"}}) do |dep|
        dep.name.should eq("foo")
        dep.resolver.is_a?(GitResolver).should be_true
        dep.resolver.source.should eq("/foo")
        dep.requirement.should eq(GitTagRef.new("test"))
      end
    end

    it "parse for git with commit requirement" do
      parse_dependency({foo: {git: "/foo", commit: "7e2e840"}}) do |dep|
        dep.name.should eq("foo")
        dep.resolver.is_a?(GitResolver).should be_true
        dep.resolver.source.should eq("/foo")
        dep.requirement.should eq(GitCommitRef.new("7e2e840"))
      end
    end

    it "parse for github" do
      parse_dependency({foo: {github: "foo/bar"}}) do |dep|
        dep.name.should eq("foo")
        dep.resolver.is_a?(GitResolver).should be_true
        dep.resolver.source.should eq("https://github.com/foo/bar.git")
      end
    end

    it "allow extra arguments" do
      parse_dependency({foo: {path: "/foo", branch: "master"}}) do |dep|
        dep.name.should eq("foo")
        dep.resolver.is_a?(PathResolver).should be_true
        dep.requirement.should eq(Any)
      end
    end
  end
end

private def parse_dependency(dep)
  pull = YAML::PullParser.new(dep.to_yaml)
  pull.read_stream do
    pull.read_document do
      pull.read_mapping do
        yield Shards::Dependency.from_yaml(pull)
      end
    end
  end
end
