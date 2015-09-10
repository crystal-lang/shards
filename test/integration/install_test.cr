require "../integration_helper"

class InstallCommandTest < Minitest::Test
  def test_installs_dependencies
    metadata = {
      dependencies: { web: "*", orm: "*", },
      development_dependencies: { mock: "*" },
      custom_dependencies: { release: "*" },
    }

    with_shard(metadata) do
      run "shards install"

      # it installed dependencies (recursively)
      assert_installed "web", "2.1.0"
      assert_installed "orm", "0.5.0"
      assert_installed "pg", "0.2.1"

      # it installed development dependencies (not recursively)
      assert_installed "mock"
      refute_installed "minitest", "0.1.3"

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
      assert_raises(FailedCommand) { run "shards install" }
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

  def test_installs_specified_group_dependencies
    metadata = {
      dependencies: { web: "*", orm: "*", },
      development_dependencies: { mock: "*" },
      custom_dependencies: { release: "*" },
    }

    with_shard(metadata) do
      run "shards install --without development --with custom"

      # it installed dependencies (recursively)
      assert_installed "web"
      assert_installed "orm"
      assert_installed "pg"

      # it didn't install development dependencies
      refute_installed "mock"
      refute_installed "minitest"

      # it installed custom dependencies (not recursively)
      assert_installed "release"
      refute_installed "optional"

      # it locked dependencies
      assert_locked "web"
      assert_locked "orm"
      assert_locked "pg"

      # it didn't lock development dependencies
      refute_locked "mock"
      refute_locked "minitest"

      # it locked custom dependencies
      assert_locked "release"
    end
  end
end
