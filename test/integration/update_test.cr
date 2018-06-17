require "../integration_helper"

class UpdateCommandTest < Minitest::Test
  def test_installs_dependencies
    metadata = {
      dependencies: { web: "*", orm: "*", },
      development_dependencies: { mock: "*" },
    }

    with_shard(metadata) do
      run "shards update"

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

  def test_updates_locked_dependencies
    metadata = {
      dependencies: { web: "2.0.0" },
      development_dependencies: { minitest: "~> 0.1.2" },
    }
    lock = { web: "1.0.0", minitest: "0.1.2" }

    with_shard(metadata, lock) do
      run "shards update"

      assert_installed "web", "2.0.0"
      assert_locked "web", "2.0.0"

      assert_installed "minitest", "0.1.3"
      assert_locked "minitest", "0.1.3"
    end
  end

  def test_updates_locked_commit
    metadata = {
      dependencies: { web: { git: git_url(:web), branch: "master" } }
    }
    lock = { web: git_commits(:web)[-5] }

    with_shard(metadata, lock) do
      run "shards update"
      assert_installed "web", "2.1.0"
    end
  end

  def test_installs_new_dependencies
    metadata = {
      dependencies: {
        web: "~> 1.1.0",
        orm: "*"
      }
    }
    lock = { web: "1.1.2" }

    with_shard(metadata, lock) do
      run "shards update"

      assert_installed "web", "1.1.2"
      assert_locked "web", "1.1.2"

      assert_installed "orm", "0.5.0"
      assert_locked "orm", "0.5.0"
    end
  end

  def test_removes_dependencies
    metadata = { dependencies: { web: "~> 1.1.0" } }
    lock = { web: "1.0.0", orm: "0.5.0" }

    with_shard(metadata, lock) do
      run "shards update"

      assert_installed "web", "1.1.2"
      assert_locked "web", "1.1.2"

      refute_installed "orm"
      refute_locked "orm"
    end
  end

  def test_finds_then_updates_new_compatible_version
    metadata = { dependencies: { web: "~> 1.1.0" } }
    lock = { web: "1.1.2" }

    with_shard(metadata, lock) do
      run "shards install"
      assert_installed "web", "1.1.2"
    end

    create_git_release "web", "1.1.3"

    with_shard(metadata, lock) do
      run "shards update"
      assert_installed "web", "1.1.3"
    end
  end

  def test_wont_generate_lockfile_for_empty_dependencies
    metadata = { dependencies: {} of Symbol => String }
    with_shard(metadata) do
      path = File.join(application_path, "shard.lock")
      refute File.exists?(path)
    end
  end

  def test_installs_executables
    metadata = {
      dependencies: {
        binary: { type: "path", path: rel_path(:binary) },
      }
    }
    with_shard(metadata) { run("shards install --no-color") }

    create_file "binary", "bin/foo", "echo 'FOO'", perm: 0o755
    create_shard "binary", "name: binary\nversion: 0.2.0\nexecutables:\n  - foobar\n  - baz\n  - foo"

    with_shard(metadata) { run("shards update --no-color") }

    foo = File.join(application_path, "bin", "foo")
    assert File.exists?(foo), "Expected to have installed bin/foo executable"
    assert_equal "FOO\n", `#{foo}`
  end
end
