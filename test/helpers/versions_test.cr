require "../test_helper"

class Shards::Helpers::VersionsTest < Minitest::Test
  include Shards::Helpers::Versions

  def versions
    ["0.0.1", "0.1.0", "0.1.1", "0.1.2", "0.2.0", "0.10.0"]
  end

  def test_resolve_requirement_gt
    assert_equal ["0.2.0", "0.10.0"], resolve_requirement(versions, "> 0.1.2")
    assert_equal ["0.1.2", "0.2.0", "0.10.0"], resolve_requirement(versions, "> 0.1.1")
  end

  def test_resolve_requirement_gte
    assert_equal ["0.2.0", "0.10.0"], resolve_requirement(versions, ">= 0.2.0")
    assert_equal ["0.1.2", "0.2.0", "0.10.0"], resolve_requirement(versions, ">= 0.1.2")
  end

  def test_resolve_requirement_lt
    assert_equal ["0.0.1"], resolve_requirement(versions, "< 0.1.0")
    assert_equal ["0.0.1", "0.1.0", "0.1.1", "0.1.2"], resolve_requirement(versions, "< 0.2.0")
  end

  def test_resolve_requirement_lte
    assert_equal ["0.0.1", "0.1.0"], resolve_requirement(versions, "<= 0.1.0")
    assert_equal ["0.0.1", "0.1.0", "0.1.1", "0.1.2", "0.2.0"], resolve_requirement(versions, "<= 0.2.0")
  end

  def test_resolve_requirement_tilde
    assert_equal ["0.1.0", "0.1.1", "0.1.2"], resolve_requirement(versions, "~> 0.1.0")
    assert_equal ["0.1.0", "0.1.1", "0.1.2", "0.2.0", "0.10.0"], resolve_requirement(versions, "~> 0.1")

    assert_equal ["0.1"], resolve_requirement(["0.1"], "~> 0.1")
    assert_equal ["0.1"], resolve_requirement(["0.1"], "~> 0.1.0")
  end
end
