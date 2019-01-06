require "minitest/autorun"
require "../src/helpers/versions"

module Shards
  class VersionRestrictionTest < Minitest::Test
    def test_resolve_requirement
      available_versions = ["0.0.1", "0.1.0", "0.1.1", "0.1.2", "0.2.0", "0.10.0"]

      assert_resolve_requirement ["0.2.0", "0.10.0"], "> 0.1.2", available_versions
      assert_resolve_requirement ["0.2.0", "0.10.0"], ">= 0.2.0", available_versions
      assert_resolve_requirement ["0.1.2", "0.2.0", "0.10.0"], ">= 0.1.2", available_versions

      assert_resolve_requirement ["0.0.1"], "< 0.1.0", available_versions
      assert_resolve_requirement ["0.0.1", "0.1.0", "0.1.1", "0.1.2"], "< 0.2.0", available_versions
      assert_resolve_requirement ["0.0.1", "0.1.0"], "<= 0.1.0", available_versions
      assert_resolve_requirement ["0.0.1", "0.1.0", "0.1.1", "0.1.2", "0.2.0"], "<= 0.2.0", available_versions

      # pending:
      # assert_resolve_requirement ["0.1.0", "0.1.1", "0.1.2"], "~> 0.1.0", available_versions
      # The current NaturalSort implementation resolves ["0.1.0", "0.1.1", "0.1.2", "0.10.0"]
      assert_resolve_requirement ["0.1.0", "0.1.1", "0.1.2", "0.2.0", "0.10.0"], "~> 0.1", available_versions
      assert_resolve_requirement ["0.1"], "~> 0.1.0", ["0.1"]
      assert_resolve_requirement ["0.1"], "~> 0.1", ["0.1"]
    end

    def assert_resolve_requirement(matching, requirement, available_versions)
      assert_equal matching, Shards::Helpers::Versions.resolve_requirement(available_versions, requirement)
    end
  end
end
