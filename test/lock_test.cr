require "./test_helper"
require "../src/lock"

module Shards
  class LockTest < Minitest::Test
    def test_parses
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

      assert_equal 2, shards.size

      assert_equal "repo", shards[0].name
      assert_equal "user/repo", shards[0]["github"]
      assert_equal "1.2.3", shards[0].version

      assert_equal "example", shards[1].name
      assert_equal "https://example.com/example-crystal.git", shards[1]["git"]
      assert_equal "0d246ee6c52d4e758651b8669a303f04be9a2a96", shards[1].refs
    end

    def test_raises_on_unknown_version
      ex = assert_raises(InvalidLock) { Lock.from_yaml("version: 99\n") }
      assert_match "Unsupported #{ LOCK_FILENAME }.", ex.message
    end

    def test_raises_on_invalid_format
      ex = assert_raises(Error) { Lock.from_yaml("") }
      assert_match "Invalid #{ LOCK_FILENAME }.", ex.message

      ex = assert_raises(Error) { Lock.from_yaml("version: 1.0\n") }
      assert_match "Invalid #{ LOCK_FILENAME }.", ex.message

      ex = assert_raises(Error) { Lock.from_yaml("version: 1.0\nshards:\n") }
      assert_match "Invalid #{ LOCK_FILENAME }.", ex.message
    end
  end
end
