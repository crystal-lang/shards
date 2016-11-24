require "../integration_helper"

class InstallCommandTest < Minitest::Test
  def test_installs_dependencies
    metadata = {
      dependencies: { web: "*", orm: "*", foo: { path: rel_path(:foo) }, },
      development_dependencies: { mock: "*" },
    }

    with_shard(metadata) do
      run "shards install"

      # it installed dependencies (recursively)
      assert_installed "web", "2.1.0"
      assert_installed "orm", "0.5.0"
      assert_installed "pg", "0.2.1"

      # it installed the path dependency
      assert_installed "foo"

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

  def test_fails_when_spec_is_missing
    Dir.cd(application_path) do
      ex = assert_raises(FailedCommand) { run "shards install --no-color" }
      assert_match "Missing #{Shards::SPEC_FILENAME}", ex.stdout
      assert_match "Please run 'shards init'", ex.stdout
    end
  end

  def test_falls_back_to_install_and_lock_current_head
    commit = git_commits(:empty).first

    with_shard({ dependencies: { empty: nil } }, nil) do
      run "shards install"
      assert_installed "empty", commit
      assert_locked "empty", commit
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

  def test_always_installs_locked_versions
    metadata = { dependencies: { minitest: "0.1.0" }, }
    lock = { minitest: "0.1.0" }

    with_shard(metadata, lock) do
      run "shards install"
      assert_installed "minitest", "0.1.0"
      assert_locked "minitest", "0.1.0"
    end

    metadata = { dependencies: { minitest: "0.1.2" }, }
    lock = { minitest: "0.1.2" }

    with_shard(metadata, lock) do
      run "shards install"
      assert_installed "minitest", "0.1.2"
      assert_locked "minitest", "0.1.2"
    end
  end

  def test_installs_dependency_at_locked_commit_when_refs_is_a_branch
    metadata = {
      dependencies: { web: { git: git_url(:web), branch: "master" } }
    }
    lock = { web: git_commits(:web)[-5] }

    with_shard(metadata, lock) do
      run "shards install"
      assert_installed "web", "1.2.0"
    end
  end

  def test_installs_dependency_at_locked_commit_when_refs_is_a_version_tag
    metadata = {
      dependencies: { web: { git: git_url(:web), tag: "v1.1.1" } }
    }
    lock = { web: git_commits(:web)[-3] }

    with_shard(metadata, lock) do
      run "shards install"
      assert_installed "web", "1.1.1"
    end
  end

  def test_updates_locked_commit
    metadata = {
      dependencies: { web: { git: git_url(:web), branch: "master" } }
    }

    with_shard(metadata, { web: git_commits(:web)[-5] }) do
      run "shards install"
      assert_installed "web", "1.2.0"
    end

    with_shard(metadata, { web: git_commits(:web)[0] }) do
      run "shards install"
      assert_installed "web", "2.1.0"
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
    metadata = { dependencies: { web: { git: git_url(:web), branch: "master" } } }

    with_shard(metadata) do
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

  def test_runs_postinstall_script
    with_shard({ dependencies: { post: "*" } }) do
      run "shards install"
      assert File.exists?(File.join(application_path, "lib", "post", "made.txt"))
    end
  end

  def test_prints_details_and_removes_dependency_when_postinstall_script_fails
    with_shard({ dependencies: { fails: "*" } }) do
      ex = assert_raises(FailedCommand) { run "shards install --no-color" }
      assert_match "E: Failed make:\n", ex.stdout
      assert_match "test -n ''\n", ex.stdout
      refute Dir.exists?(File.join(application_path, "lib", "fails"))
    end
  end

  def test_fails_when_shard_name_doesnt_match
    metadata = {
      dependencies: {
        typo: { git: git_url(:mock), version: "*" }
      }
    }
    with_shard(metadata) do
      ex = assert_raises(FailedCommand) { run "shards install --no-color" }
      assert_match "Error shard name (mock) doesn't match dependency name (typo)", ex.stdout
    end
  end
end
