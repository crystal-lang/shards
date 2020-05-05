require "./spec_helper"

describe "lock" do
  it "fails when spec is missing" do
    Dir.cd(application_path) do
      ex = expect_raises(FailedCommand) { run "shards lock --no-color" }
      ex.stdout.should contain("Missing #{Shards::SPEC_FILENAME}")
      ex.stdout.should contain("Please run 'shards init'")
    end
  end

  it "doesn't generate lockfile when project has no dependencies" do
    with_shard({name: "test"}) do
      run "shards lock"
      File.exists?(File.join(application_path, "shard.lock")).should be_false
    end
  end

  it "creates lockfile" do
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

  it "locks is consistent with lockfile" do
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

  it "locks new dependencies" do
    metadata = {dependencies: {web: "~> 1.0.0", orm: "*"}}
    lock = {web: "1.0.0"}

    with_shard(metadata, lock) do
      run "shards lock"

      assert_locked "web", "1.0.0"
      assert_locked "orm", "0.5.0"
      assert_locked "pg", "0.2.1"
    end
  end

  it "removes dependencies" do
    metadata = {dependencies: {web: "~> 1.0.0"}}
    lock = {web: "1.0.0", orm: "0.5.0", pg: "0.2.1"}

    with_shard(metadata, lock) do
      run "shards lock"

      assert_locked "web", "1.0.0"
      refute_locked "orm", "0.5.0"
      refute_locked "pg", "0.2.1"
    end
  end

  it "updates lockfile" do
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

  it "doesn't change lockfile if there are no changes" do
    metadata = {
      dependencies:             {web: "~> 1.0"},
      development_dependencies: {minitest: "~> 0.1"},
    }

    lock_path = File.join(application_path, "shard.lock")

    with_shard(metadata) do
      run "shards lock"
      mtime_before = File.info(lock_path).modification_time
      sleep 1
      run "shards lock"
      mtime_after = File.info(lock_path).modification_time

      mtime_after.should eq mtime_before
    end
  end
end
