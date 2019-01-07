require "../test_helper"

class Shards::Helpers::NaturalSortTest < Minitest::Test
  include Shards::Helpers::NaturalSort

  def test_natural_compare
    # a is older than b:
    assert_equal 1, natural_compare("1.0.0", "1.0.1")
    assert_equal 1, natural_compare("1.0.0", "2.0.0")
    assert_equal 1, natural_compare("1.0", "1.0.0.1")
    assert_equal 1, natural_compare("1.0.0", "1.0.0.1")

    # a == b
    assert_equal 0, natural_compare("0.1", "0.1")
    assert_equal 0, natural_compare("0.1", "0.1.0.0")
    assert_equal 0, natural_compare("0.1.0", "0.1")
    assert_equal 0, natural_compare("2.0.0", "2.0.0")

    # a is newer than b:
    assert_equal -1, natural_compare("1.0.1", "1.0.0")
    assert_equal -1, natural_compare("2.0.0", "1.0.0")
    assert_equal -1, natural_compare("1.0.0.1", "1.0")
    assert_equal -1, natural_compare("1.0.0.1", "1.0.0")
  end

  def test_natural_sort
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
        1.0.0
      ).shuffle

      assert_equal %w(
        1.0.0
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
      ), natural_sort(versions)
    end
  end
end
