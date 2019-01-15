require "../integration_helper"

class UpdateCommandTest < Minitest::Test
  def test_installs_dependencies
    metadata = {
      dependencies:             {web: "*", orm: "*"},
      development_dependencies: {mock: "*"},
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
      dependencies:             {web: "2.0.0"},
      development_dependencies: {minitest: "~> 0.1.2"},
    }
    lock = {web: "1.0.0", minitest: "0.1.2"}

    with_shard(metadata, lock) do
      run "shards update"

      assert_installed "web", "2.0.0"
      assert_locked "web", "2.0.0"

      assert_installed "minitest", "0.1.3"
      assert_locked "minitest", "0.1.3"
    end
  end

  def test_wont_install_prerelease_version
    metadata = { dependencies: {unstable: "*"} }
    lock = {unstable: "0.1.0"}

    with_shard(metadata, lock) do
      run "shards update"
      assert_installed "unstable", "0.2.0"
      assert_locked "unstable", "0.2.0"
    end
  end

  def test_installs_specified_prerelease_version
    metadata = { dependencies: {unstable: "~> 0.3.0.alpha"} }
    lock = {unstable: "0.3.0.alpha"}

    with_shard(metadata, lock) do
      run "shards update"
      assert_installed "unstable", "0.3.0.beta"
      assert_locked "unstable", "0.3.0.beta"
    end
  end

  def test_updates_locked_specified_prerelease
    metadata = { dependencies: {unstable: "~> 0.3.0.alpha"} }
    lock = {unstable: "0.3.0.alpha"}

    with_shard(metadata, lock) do
      run "shards update"
      assert_installed "unstable", "0.3.0.beta"
      assert_locked "unstable", "0.3.0.beta"
    end
  end

  def test_updates_from_prerelease_to_release_with_approximate_operator
    metadata = { dependencies: {preview: "~> 0.3.0.a"} }
    lock = {preview: "0.3.0.alpha"}

    with_shard(metadata, lock) do
      run "shards update"
      assert_installed "preview", "0.3.0"
      assert_locked "preview", "0.3.0"
    end
  end

  # TODO: detect version, and prefer release (0.3.0) over further prereleases (?)
  def test_updates_to_latest_prerelease_with_gte_operator
    metadata = { dependencies: {preview: ">= 0.3.0.a"} }
    lock = {preview: "0.3.0.a"}

    with_shard(metadata, lock) do
      run "shards update"
      assert_installed "preview", "0.4.0.a"
      assert_locked "preview", "0.4.0.a"
    end
  end

  def test_updates_locked_commit
    metadata = {
      dependencies: {web: {git: git_url(:web), branch: "master"}},
    }
    lock = {web: git_commits(:web)[-5]}

    with_shard(metadata, lock) do
      run "shards update"
      assert_installed "web", "2.1.0"
    end
  end

  def test_installs_new_dependencies
    metadata = {
      dependencies: {
        web: "~> 1.1.0",
        orm: "*",
      },
    }
    lock = {web: "1.1.2"}

    with_shard(metadata, lock) do
      run "shards update"

      assert_installed "web", "1.1.2"
      assert_locked "web", "1.1.2"

      assert_installed "orm", "0.5.0"
      assert_locked "orm", "0.5.0"
    end
  end

  def test_removes_dependencies
    metadata = {dependencies: {web: "~> 1.1.0"}}
    lock = {web: "1.0.0", orm: "0.5.0"}

    with_shard(metadata, lock) do
      run "shards update"

      assert_installed "web", "1.1.2"
      assert_locked "web", "1.1.2"

      refute_installed "orm"
      refute_locked "orm"
    end
  end

  def test_finds_then_updates_new_compatible_version
    create_git_repository "oopsie", "1.1.0", "1.2.0"

    metadata = {dependencies: {oopsie: "~> 1.1.0"}}
    lock = {oopsie: "1.1.0"}

    with_shard(metadata, lock) do
      run "shards install"
      assert_installed "oopsie", "1.1.0"
    end

    create_git_release "oopsie", "1.1.1"

    with_shard(metadata, lock) do
      run "shards update"
      assert_installed "oopsie", "1.1.1"
    end
  end

  def test_wont_generate_lockfile_for_empty_dependencies
    metadata = {dependencies: {} of Symbol => String}
    with_shard(metadata) do
      path = File.join(application_path, "shard.lock")
      refute File.exists?(path)
    end
  end

  def test_installs_executables
    metadata = {
      dependencies: {
        binary: {type: "path", path: rel_path(:binary)},
      },
    }
    with_shard(metadata) { run("shards install --no-color") }

    create_file "binary", "bin/foo", "echo 'FOO'", perm: 0o755
    create_shard "binary", "name: binary\nversion: 0.2.0\nexecutables:\n  - foobar\n  - baz\n  - foo"

    with_shard(metadata) { run("shards update --no-color") }

    foo = File.join(application_path, "bin", "foo")
    assert File.exists?(foo), "Expected to have installed bin/foo executable"
    assert_equal "FOO\n", `#{foo}`
  end

  def test_doesnt_update_local_cache
    metadata = {
      dependencies: { local_cache: "*" },
    }

    with_shard(metadata) do
      # error: dependency isn't in local cache
      ex = assert_raises(FailedCommand) { run("shards install --local --no-color") }
      assert_match %(E: Missing repository cache for "local_cache".), ex.stdout
    end

    # re-run without --local to install the dependency:
    create_git_repository "local_cache", "1.0", "2.0"
    with_shard(metadata) { run("shards install") }
    assert_locked "local_cache", "2.0"

    # create a new release:
    create_git_release "local_cache", "3.0"

    # re-run with --local, which won't find the new release:
    with_shard(metadata) { run("shards update --local") }
    assert_locked "local_cache", "2.0"

    # run again without --local, which will find & install the new release:
    with_shard(metadata) { run("shards update") }
    assert_locked "local_cache", "3.0"
  end
end
