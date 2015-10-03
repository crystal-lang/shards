require "../integration_helper"

class CheckCommandTest < Minitest::Test
  def test_lists_all_dependencies
    metadata = {
      dependencies: { web: "*", orm: "*", },
      development_dependencies: { mock: "*" }
    }
    with_shard(metadata) do
      run "shards install"
      stdout = run "shards list", capture: true
      assert_match "web (2.1.0)", stdout
      assert_match "orm (0.5.0)", stdout
      assert_match "pg (0.2.1)", stdout
      assert_match "mock (0.1.0)", stdout
      assert_match "shoulda (0.1.0)", stdout
    end
  end

  def test_production_doesnt_list_development_dependencies
    metadata = {
      dependencies: { web: "*", orm: "*", },
      development_dependencies: { mock: "*" }
    }
    with_shard(metadata) do
      run "shards install --production"
      stdout = run "shards list --production", capture: true
      assert_match "web (2.1.0)", stdout
      assert_match "orm (0.5.0)", stdout
      assert_match "pg (0.2.1)", stdout
      refute_match "mock (0.1.0)", stdout
      refute_match "shoulda (0.1.0)", stdout
    end
  end
end
