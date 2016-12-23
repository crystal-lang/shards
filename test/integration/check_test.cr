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
    with_shard({ dependencies: { web: "1.2.0" } }) do
      run "shards install"
    end

    with_shard({ dependencies: { web: "~> 1.1" } }) do
      run "shards check"
    end
  end

  def test_fails_without_lockfile
    with_shard({ dependencies: { web: "*" } }) do
      ex = assert_raises(FailedCommand) { run "shards check --no-color" }
      assert_match "Missing #{ Shards::LOCK_FILENAME }", ex.stdout
      assert_empty ex.stderr
    end
  end

  def test_succeeds_without_dependencies_and_lockfile
    with_shard({ name: "no_dependencies" }) do
      run "shards check --no-color"
    end
  end

  def test_fails_when_dependencies_are_missing
    with_shard({ dependencies: { web: "*" } }) do
      run "shards install"
    end

    metadata = {
      dependencies: { web: "*", orm: "*", },
      development_dependencies: { mock: "*" }
    }
    with_shard(metadata) do
      ex = assert_raises(FailedCommand) { run "shards check --no-color" }
      assert_match "Dependencies aren't satisfied", ex.stdout
      assert_empty ex.stderr
    end
  end

  def test_fails_when_wrong_versions_are_installed
    with_shard({ dependencies: { web: "1.0.0" } }) do
      run "shards install"
    end

    with_shard({ dependencies: { web: "2.0.0" } }) do
      ex = assert_raises(FailedCommand) { run "shards check --no-color" }
      assert_match "Dependencies aren't satisfied", ex.stdout
      assert_empty ex.stderr
    end
  end
end
