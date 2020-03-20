require "./spec_helper"
require "../src/lock"

module Shards
  describe Lock do
    it "parses" do
      shards = Lock.from_yaml <<-YAML
      version: 1.0
      shards:
        repo:
          github: user/repo
          version: 1.2.3
        example:
          git: https://example.com/example-crystal.git
          commit: 0d246ee6c52d4e758651b8669a303f04be9a2a96
      YAML

      shards.size.should eq(2)

      shards[0].name.should eq("repo")
      shards[0]["github"].should eq("user/repo")
      shards[0].version.should eq("1.2.3")

      shards[1].name.should eq("example")
      shards[1]["git"].should eq("https://example.com/example-crystal.git")
      shards[1].refs.should eq("0d246ee6c52d4e758651b8669a303f04be9a2a96")
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
