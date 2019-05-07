require "../integration_helper"

class CheckCommandTest < Minitest::Test
  def test_succeeds_without_dependencies_and_lockfile
    with_shard({name: "no_dependencies"}) do
      run "shards purge"
    end
    assert Dir.empty?(Shards.cache_path)
  end
end
