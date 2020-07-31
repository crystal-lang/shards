require "./spec_helper"
require "../../src/lock"

module Shards
  describe Lock do
    it "parses" do
      create_git_repository "library", "0.1.0"

      lock = Lock.from_yaml <<-YAML
      version: 1.0
      shards:
        repo:
          github: user/repo
          version: 1.2.3
        example:
          git: #{git_url(:library)}
          commit: #{git_commits(:library)[0]}
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
      shards[0].version.should eq(version "1.2.3")
      shards[0].to_s.should eq("repo (1.2.3)")

      shards[1].name.should eq("example")
      shards[1].resolver.should eq(GitResolver.new("example", git_url(:library)))
      shards[1].version.should eq(version "0.1.0+git.commit.#{git_commits(:library)[0]}")
      shards[1].to_s.should eq("example (0.1.0 at #{git_commits(:library)[0][0...7]})")

      shards[2].name.should eq("new_git")
      shards[2].resolver.should eq(GitResolver.new("new_git", "https://example.com/new.git"))
      shards[2].version.should eq(version "1.2.3+git.commit.0d246ee6c52d4e758651b8669a303f04be9a2a96")
      shards[2].to_s.should eq("new_git (1.2.3 at 0d246ee)")

      shards[3].name.should eq("new_path")
      shards[3].resolver.should eq(PathResolver.new("new_path", "../path"))
      shards[3].version.should eq(version "0.1.2")
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
