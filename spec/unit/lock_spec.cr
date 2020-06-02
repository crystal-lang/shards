require "./spec_helper"
require "../../src/lock"

module Shards
  describe Lock do
    it "parses" do
      lock = Lock.from_yaml <<-YAML
      version: 1.0
      shards:
        repo:
          github: user/repo
          version: 1.2.3
        example:
          git: https://example.com/example-crystal.git
          commit: 0d246ee6c52d4e758651b8669a303f04be9a2a96
        new_git:
          git: https://example.com/new.git
          version: 1.2.3+git.commit.0d246ee6c52d4e758651b8669a303f04be9a2a96
        new_path:
          path: ../path
          version: 0.1.2
      YAML

      lock.version.should eq("1.0")

      shards = lock.shards
      shards.size.should eq(4)

      shards[0].name.should eq("repo")
      shards[0].resolver.should eq(GitResolver.new("repo", "https://github.com/user/repo.git"))
      shards[0].requirement.should eq(version "1.2.3")
      shards[0].to_s.should eq("repo (1.2.3)")

      shards[1].name.should eq("example")
      shards[1].resolver.should eq(GitResolver.new("example", "https://example.com/example-crystal.git"))
      shards[1].requirement.should eq(commit "0d246ee6c52d4e758651b8669a303f04be9a2a96")
      shards[1].to_s.should eq("example (commit 0d246ee)")

      shards[2].name.should eq("new_git")
      shards[2].resolver.should eq(GitResolver.new("new_git", "https://example.com/new.git"))
      shards[2].requirement.should eq(version "1.2.3+git.commit.0d246ee6c52d4e758651b8669a303f04be9a2a96")
      shards[2].to_s.should eq("new_git (1.2.3 at 0d246ee)")

      shards[3].name.should eq("new_path")
      shards[3].resolver.should eq(PathResolver.new("new_path", "../path"))
      shards[3].requirement.should eq(version "0.1.2")
      shards[3].to_s.should eq("new_path (0.1.2 at ../path)")
    end

    it "raises on unknown version" do
      expect_raises(InvalidLock, "Unsupported #{LOCK_FILENAME}.") { Lock.from_yaml("version: 99\n") }
    end

    it "raises on invalid format" do
      expect_raises(Error, "Invalid #{LOCK_FILENAME}.") { Lock.from_yaml("") }

      expect_raises(Error, "Invalid #{LOCK_FILENAME}.") { Lock.from_yaml("version: 1.0\n") }

      expect_raises(Error, "Invalid #{LOCK_FILENAME}.") { Lock.from_yaml("version: 1.0\nshards:\n") }
    end
  end
end
