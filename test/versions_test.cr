require "./test_helper"

module Shards
  class VersionsTest < Minitest::Test
    def test_compare
      # a is older than b:
      assert_equal 1, Versions.compare("1.0.0", "1.0.1")
      assert_equal 1, Versions.compare("1.0.0", "2.0.0")
      assert_equal 1, Versions.compare("1.0", "1.0.0.1")
      assert_equal 1, Versions.compare("1.0.0", "1.0.0.1")

      # a == b
      assert_equal 0, Versions.compare("0.1", "0.1")
      assert_equal 0, Versions.compare("0.1", "0.1.0.0")
      assert_equal 0, Versions.compare("0.1.0", "0.1")
      assert_equal 0, Versions.compare("2.0.0", "2.0.0")

      # a is newer than b:
      assert_equal -1, Versions.compare("1.0.1", "1.0.0")
      assert_equal -1, Versions.compare("2.0.0", "1.0.0")
      assert_equal -1, Versions.compare("1.0.0.1", "1.0")
      assert_equal -1, Versions.compare("1.0.0.1", "1.0.0")
    end

    def test_compare_preversions
      # a is older than b:
      assert_equal 1, Versions.compare("1.0.0-beta", "1.0.0")
      assert_equal 1, Versions.compare("1.0.0.alpha", "1.0.0")
      assert_equal 1, Versions.compare("1.0.0.alpha", "1.0.0.beta")
      assert_equal 1, Versions.compare("1.0.beta", "1.0.0")
      assert_equal 1, Versions.compare("1.0.alpha", "1.0.0-beta")

      assert_equal 1, Versions.compare("1.0-pre1", "1.0-pre2")
      assert_equal 1, Versions.compare("1.0-pre2", "1.0-pre10")

      # a == b
      assert_equal 0, Versions.compare("1.0.0-beta", "1.0.0-beta")
      assert_equal 0, Versions.compare("1.0.0-alpha", "1.0.0.alpha")
      assert_equal 0, Versions.compare("1.0.beta", "1.0.0.beta")
      assert_equal 0, Versions.compare("1.0.beta", "1.0.0.0.0.0.beta")

      # a is newer than b:
      assert_equal -1, Versions.compare("1.0.0", "1.0.0-beta")
      assert_equal -1, Versions.compare("1.0.0", "1.0.0.alpha")
      assert_equal -1, Versions.compare("1.0.0.beta", "1.0.0.alpha")
      assert_equal -1, Versions.compare("1.0.0", "1.0.beta")
      assert_equal -1, Versions.compare("1.0.0-beta", "1.0.alpha")

      assert_equal -1, Versions.compare("1.0-pre2", "1.0-pre1")
      assert_equal -1, Versions.compare("1.0-pre10", "1.0-pre2")
    end

    def test_sort
      100.times do
        versions = %w(
          0.0.1
          0.1.0
          0.1.1
          0.1.2
          0.2.0
          0.2.1
          0.2.10
          0.2.10.1
          0.2.11
          0.10.0
          0.11.0
          0.20.0
          0.20.1
          1.0.0-alpha
          1.0.0.beta
          1.0.0-pre1
          1.0.0-pre2
          1.0.0-rc1
          1.0.0-rc2
          1.0.0-rc10
          1.0.0
        ).shuffle

        assert_equal %w(
          1.0.0
          1.0.0-rc10
          1.0.0-rc2
          1.0.0-rc1
          1.0.0-pre2
          1.0.0-pre1
          1.0.0.beta
          1.0.0-alpha
          0.20.1
          0.20.0
          0.11.0
          0.10.0
          0.2.11
          0.2.10.1
          0.2.10
          0.2.1
          0.2.0
          0.1.2
          0.1.1
          0.1.0
          0.0.1
        ), Versions.sort(versions)
      end
    end

    def versions
      ["0.0.1", "0.1.0", "0.1.1", "0.1.2", "0.2.0", "0.10.0"]
    end

    def test_resolve_any
      assert_equal versions, Versions.resolve(versions, "*")
    end

    def test_resolve_eq
      assert_equal ["0.2.0"], Versions.resolve(versions, "0.2.0")
      assert_equal ["0.1.1"], Versions.resolve(versions, "0.1.1")
      assert_equal ["0.10.0"], Versions.resolve(versions, "0.10.0")
      assert_empty Versions.resolve(versions, "1.0.0")
      assert_empty Versions.resolve(versions, "0.0.1.alpha")
    end

    def test_resolve_gt
      assert_equal ["0.2.0", "0.10.0"], Versions.resolve(versions, "> 0.1.2")
      assert_equal ["0.1.2", "0.2.0", "0.10.0"], Versions.resolve(versions, "> 0.1.1")
    end

    def test_resolve_gte
      assert_equal ["0.2.0", "0.10.0"], Versions.resolve(versions, ">= 0.2.0")
      assert_equal ["0.1.2", "0.2.0", "0.10.0"], Versions.resolve(versions, ">= 0.1.2")
    end

    def test_resolve_lt
      assert_equal ["0.0.1"], Versions.resolve(versions, "< 0.1.0")
      assert_equal ["0.0.1", "0.1.0", "0.1.1", "0.1.2"], Versions.resolve(versions, "< 0.2.0")
    end

    def test_resolve_lte
      assert_equal ["0.0.1", "0.1.0"], Versions.resolve(versions, "<= 0.1.0")
      assert_equal ["0.0.1", "0.1.0", "0.1.1", "0.1.2", "0.2.0"], Versions.resolve(versions, "<= 0.2.0")
    end

    def test_resolve_approximate
      assert_equal ["0.1.0", "0.1.1", "0.1.2"], Versions.resolve(versions, "~> 0.1.0")
      assert_equal ["0.1.0", "0.1.1", "0.1.2", "0.2.0", "0.10.0"], Versions.resolve(versions, "~> 0.1")

      assert_equal ["0.1"], Versions.resolve(["0.1"], "~> 0.1")
      assert_equal ["0.1"], Versions.resolve(["0.1"], "~> 0.1.0")
    end
  end
end
