require "../integration_helper"

class CheckCommandTest < Minitest::Test
  def test_succeeds_when_all_dependencies_are_installed
    metadata = {
      dependencies: { web: "*", orm: "*", },
      development_dependencies: { mock: "*" }
    }
    with_shard(metadata) do
      run "shards install"
      run "shards check"
    end
  end

  def test_succeeds_when_dependencies_match_loose_requirements
    metadata = {
      dependencies: { web: "1.2.0" },
    }
    with_shard(metadata) do
      run "shards install"
    end

    metadata = {
      dependencies: { web: "~> 1.1" },
    }
    with_shard(metadata) do
      run "shards check"
    end
  end

  def test_fails_when_dependencies_are_missing
    metadata = {
      dependencies: { web: "*" }
    }
    with_shard(metadata) { run "shards install" }

    metadata = {
      dependencies: { web: "*", orm: "*", },
      development_dependencies: { mock: "*" }
    }
    with_shard(metadata) do
      assert_raises(FailedCommand) { run "shards check" }
    end
  end

  def test_fails_when_wrong_versions_are_installed
    metadata = {
      dependencies: { web: "1.0.0" }
    }
    with_shard(metadata) { run "shards install" }

    metadata = {
      dependencies: { web: "2.0.0" }
    }
    with_shard(metadata) do
      assert_raises(FailedCommand) { run "shards check" }
    end
  end
end
