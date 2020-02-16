require "./test_helper"

class Shards::DependencyTest < Minitest::Test
  def test_version
    dependency = Dependency.new("app")
    assert_equal "*", dependency.version

    dependency = Dependency.new("app", {version: "*"})
    assert_equal "*", dependency.version

    dependency = Dependency.new("app", {version: "1.0.0"})
    assert_equal "1.0.0", dependency.version

    dependency = Dependency.new("app", {version: "<= 2.0.0"})
    assert_equal "<= 2.0.0", dependency.version
  end

  def test_version_with_tags
    dependency = Dependency.new("app", {tag: "fix/something"})
    assert_equal "*", dependency.version

    dependency = Dependency.new("app", {tag: "1.2.3"})
    assert_equal "*", dependency.version

    # version tag is considered a version:
    dependency = Dependency.new("app", {tag: "v1.2.3-pre1"})
    assert_equal "1.2.3-pre1", dependency.version
  end
end
