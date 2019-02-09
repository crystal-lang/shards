require "../integration_helper"

class LockCommandTest < Minitest::Test
  def test_fails_when_spec_is_missing
    Dir.cd(application_path) do
      ex = assert_raises(FailedCommand) { run "shards lock --no-color" }
      assert_match "Missing #{Shards::SPEC_FILENAME}", ex.stdout
      assert_match "Please run 'shards init'", ex.stdout
    end
  end

  def test_doesnt_generate_lockfile_when_project_has_no_dependencies
    with_shard({name: "test"}) do
      run "shards lock"
      refute File.exists?(File.join(application_path, "shard.lock"))
    end
  end

  def test_creates_lockfile
    metadata = {
      dependencies:             {web: "*", orm: "*", foo: {path: rel_path(:foo)}},
      development_dependencies: {mock: "*"},
    }

    with_shard(metadata) do
      run "shards lock"

      # it locked dependencies (recursively):
      assert_locked "web", "2.1.0"
      assert_locked "orm", "0.5.0"
      assert_locked "pg", "0.2.1"

      # it locked development dependencies (not recursively)
      assert_locked "mock", "0.1.0"
      refute_locked "minitest"

      # it didn't install anything:
      refute_installed "web"
      refute_installed "orm"
      refute_installed "pg"
      refute_installed "foo"
      refute_installed "mock"
      refute_installed "shoulda"
    end
  end

  def test_locks_is_consistent_with_lockfile
    metadata = {
      dependencies:             {web: "*"},
      development_dependencies: {minitest: "~> 0.1"},
    }
    lock = {web: "1.0.0", minitest: "0.1.2"}

    with_shard(metadata, lock) do
      run "shards lock"

      assert_locked "web", "1.0.0"
      assert_locked "minitest", "0.1.2"
    end
  end

  def test_locks_new_dependencies
    metadata = {dependencies: {web: "~> 1.0.0", orm: "*"}}
    lock = {web: "1.0.0"}

    with_shard(metadata, lock) do
      run "shards lock"

      assert_locked "web", "1.0.0"
      assert_locked "orm", "0.5.0"
      assert_locked "pg", "0.2.1"
    end
  end

  def test_removes_dependencies
    metadata = {dependencies: {web: "~> 1.0.0"}}
    lock = {web: "1.0.0", orm: "0.5.0", pg: "0.2.1"}

    with_shard(metadata, lock) do
      run "shards lock"

      assert_locked "web", "1.0.0"
      refute_locked "orm", "0.5.0"
      refute_locked "pg", "0.2.1"
    end
  end

  def test_updates_lockfile
    metadata = {
      dependencies:             {web: "~> 1.0"},
      development_dependencies: {minitest: "~> 0.1"},
    }
    lock = {web: "1.0.0", minitest: "0.1.2"}

    with_shard(metadata, lock) do
      run "shards lock --update"

      assert_locked "web", "1.2.0"
      assert_locked "minitest", "0.1.3"
    end
  end
end
