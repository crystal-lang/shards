require "../integration_helper"

class InstallCommandTest < Minitest::Test
  def test_installs_dependencies
    metadata = {
      dependencies: { web: "*", orm: "*", },
      development_dependencies: { mock: "*" },
    }

    with_shard(metadata) do
      run "shards install"

      # it installed dependencies (recursively)
      assert_installed "web", "2.1.0"
      assert_installed "orm", "0.5.0"
      assert_installed "pg", "0.2.1"

      # it installed development dependencies (recursively, except their
      # development dependencies)
      assert_installed "mock"
      assert_installed "shoulda", "0.1.0"
      refute_installed "minitest"

      # it didn't install custom dependencies
      refute_installed "release"

      # it locked dependencies
      assert_locked "web", "2.1.0"
      assert_locked "orm", "0.5.0"
      assert_locked "pg", "0.2.1"

      # it locked development dependencies (not recursively)
      assert_locked "mock", "0.1.0"
      refute_locked "minitest"

      # it didn't lock custom dependencies
      refute_locked "release"
    end
  end

  def test_installs_dependencies_at_locked_version
    metadata = {
      dependencies: { web: "1.0.0" },
      development_dependencies: { minitest: "~> 0.1.2" },
    }
    lock = { web: "1.0.0", minitest: "0.1.2" }

    with_shard(metadata, lock) do
      run "shards install"

      assert_installed "web", "1.0.0"
      assert_locked "web", "1.0.0"

      assert_installed "minitest", "0.1.2"
      assert_locked "minitest", "0.1.2"
    end
  end

  def test_fails_to_install_when_dependency_requirement_changed
    metadata = { dependencies: { web: "2.0.0" }, }
    lock = { web: "1.0.0" }

    with_shard(metadata, lock) do
      ex = assert_raises(FailedCommand) { run "shards install --no-color" }
      assert_match "Outdated shard.lock", ex.stdout
      assert_empty ex.stderr
      refute_installed "web"
    end
  end

  def test_installs_and_updates_lockfile_for_added_dependencies
    metadata = {
      dependencies: {
        web: "~> 1.0.0",
        orm: "*"
      }
    }
    lock = { web: "1.0.0" }

    with_shard(metadata, lock) do
      run "shards install"

      assert_installed "web", "1.0.0"
      assert_locked "web", "1.0.0"

      assert_installed "orm", "0.5.0"
      assert_locked "orm", "0.5.0"
    end
  end

  def test_updated_lockfile_on_removed_dependencies
    metadata = { dependencies: { web: "~> 1.0.0" } }
    lock = { web: "1.0.0", orm: "0.5.0" }

    with_shard(metadata, lock) do
      run "shards install"

      assert_installed "web", "1.0.0"
      assert_locked "web", "1.0.0"

      refute_installed "orm", "0.5.0"
      refute_locked "orm", "0.5.0"
    end
  end

  def test_locks_commit_when_installing_git_refs
    with_shard({ dependencies: { web: { branch: "master" } } }) do
      run "shards install"
      assert_locked "web", git_commits(:web).first
    end
  end

  def test_production_doesnt_install_development_dependencies
    metadata = {
      dependencies: { web: "*", orm: "*", },
      development_dependencies: { mock: "*" },
    }

    with_shard(metadata) do
      run "shards install --production"

      # it installed dependencies (recursively)
      assert_installed "web"
      assert_installed "orm"
      assert_installed "pg"

      # it didn't install development dependencies
      refute_installed "mock"
      refute_installed "minitest"

      # it didn't generate lock file
      refute File.exists?(File.join(application_path, "shard.lock")),
        "expected lock file to not have been generated"
    end
  end

  def test_production_doesnt_install_new_dependencies
    metadata = {
      dependencies: {
        web: "~> 1.0.0",
        orm: "*"
      }
    }
    lock = { web: "1.0.0" }

    with_shard(metadata, lock) do
      ex = assert_raises(FailedCommand) { run "shards install --production --no-color" }
      assert_match "Outdated shard.lock", ex.stdout
      assert_empty ex.stderr
    end
  end

  def test_doesnt_generate_lockfile_when_project_has_no_dependencies
    with_shard({ name: "test" }) do
      run "shards install"

      refute File.exists?(File.join(application_path, "shard.lock")),
        "expected shard.lock to not have been generated"
    end
  end
end
