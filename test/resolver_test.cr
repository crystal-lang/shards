require "./test_helper"

module Shards
  class ResolverTest < Minitest::Test
    def test_find_resolver_with_unordered_dependency_keys
      dependency = Dependency.new("test", {
        "branch" => "master",
        "git" => "file:///tmp/test"
      })
      assert_equal GitResolver, Shards.find_resolver(dependency).class
    end
  end
end
