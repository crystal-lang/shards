require "./test_helper"
require "../src/helpers/natural_sort"

module Shards
  class NaturalSortTest < Minitest::Test
    # See https://github.com/crystal-lang/shards/issues/162
    def test_supports_big_numbers
      result = Shards::Helpers::NaturalSort.sort("341678090110cdb5436f75cc796c785ed392c4be", "0.1.0")
      assert_equal -1, result
    end
  end
end
