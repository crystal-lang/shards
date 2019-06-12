require "../integration_helper"

class InstallCommandTest < Minitest::Test
  def test_installs_dependencies
    metadata = {
      dependencies:             {web: "*", orm: "*", foo: {path: rel_path(:foo)}},
      development_dependencies: {mock: "*"},
    }

    with_shard(metadata) do
      run "shards install"

      # it installed dependencies (recursively)
      assert_installed "web", "2.1.0"
      assert_installed "orm", "0.5.0"
      assert_installed "pg", "0.2.1"

      # it installed the path dependency
      assert_installed "foo", "0.1.0"

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

  def test_wont_install_prerelease_version
    metadata = {
      dependencies: {unstable: "*"},
    }
    with_shard(metadata) do
      run "shards install"
      assert_installed "unstable", "0.2.0"
      assert_locked "unstable", "0.2.0"
    end
  end

  def test_installs_specified_prerelease_version
    metadata = {
      dependencies: {unstable: "0.3.0.alpha"},
    }
    with_shard(metadata) do
      run "shards install"
      assert_installed "unstable", "0.3.0.alpha"
      assert_locked "unstable", "0.3.0.alpha"
    end
  end

  def test_installs_prerelease_version_at_refs
    metadata = {
      dependencies: {
        unstable: {git: git_url(:unstable), branch: "master"}
      }
    }
    with_shard(metadata) do
      run "shards install"
      assert_installed "unstable", "0.3.0.beta"
    end
  end

  def test_installs_dependencies_at_locked_version
    metadata = {
      dependencies:             {web: "1.0.0"},
      development_dependencies: {minitest: "~> 0.1.2"},
    }
    lock = {web: "1.0.0", minitest: "0.1.2"}

    with_shard(metadata, lock) do
      run "shards install"

      assert_installed "web", "1.0.0"
      assert_locked "web", "1.0.0"

      assert_installed "minitest", "0.1.2"
      assert_locked "minitest", "0.1.2"
    end
  end

  def test_always_installs_locked_versions
    metadata = {dependencies: {minitest: "0.1.0"}}
    lock = {minitest: "0.1.0"}

    with_shard(metadata, lock) do
      run "shards install"
      assert_installed "minitest", "0.1.0"
      assert_locked "minitest", "0.1.0"
    end

    metadata = {dependencies: {minitest: "0.1.2"}}
    lock = {minitest: "0.1.2"}

    with_shard(metadata, lock) do
      run "shards install"
      assert_installed "minitest", "0.1.2"
      assert_locked "minitest", "0.1.2"
    end
  end

  def test_resolves_dependency_at_head_when_no_version_tags
    metadata = {dependencies: {"missing": "*"}}
    with_shard(metadata) { run "shards install" }
    assert_installed "missing", "0.1.0"
  end

  def test_installs_dependency_at_locked_commit_when_refs_is_a_branch
    metadata = {
      dependencies: {
        web: {git: git_url(:web), branch: "master"}
      },
    }
    lock = {web: git_commits(:web)[-5]}

    with_shard(metadata, lock) do
      run "shards install"
      assert_installed "web", "1.2.0"
    end
  end

  def test_installs_dependency_at_locked_commit_when_refs_is_a_version_tag
    metadata = {
      dependencies: {web: {git: git_url(:web), tag: "v1.1.1"}},
    }
    lock = {web: git_commits(:web)[-3]}

    with_shard(metadata, lock) do
      run "shards install"
      assert_installed "web", "1.1.1"
    end
  end

  def test_resolves_dependency_spec_at_locked_commit
    create_git_repository "locked"
    create_git_release "locked", "0.1.0", "name: locked\nversion: 0.1.0\n"
    create_git_release "locked", "0.2.0", "name: locked\nversion: 0.2.0\ndependencies:\n  pg:\n    git: #{git_path("pg")}\n"

    metadata = {
      dependencies: {
        "locked": {git: git_path(:"locked"), branch: "master"},
      }
    }
    lock = {
      "locked": git_commits(:"locked").last
    }
    with_shard(metadata, lock) { run "shards install" }

    assert_installed "locked", "0.1.0"
    refute_installed "pg"
  end

  def test_updates_locked_commit
    metadata = {
      dependencies: {web: {git: git_url(:web), branch: "master"}},
    }

    with_shard(metadata, {web: git_commits(:web)[-5]}) do
      run "shards install"
      assert_installed "web", "1.2.0"
    end

    with_shard(metadata, {web: git_commits(:web)[0]}) do
      run "shards install"
      assert_installed "web", "2.1.0"
    end
  end

  def test_fails_to_install_when_dependency_requirement_changed
    metadata = {dependencies: {web: "2.0.0"}}
    lock = {web: "1.0.0"}

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
        orm: "*",
      },
    }
    lock = {web: "1.0.0"}

    with_shard(metadata, lock) do
      run "shards install"

      assert_installed "web", "1.0.0"
      assert_locked "web", "1.0.0"

      assert_installed "orm", "0.5.0"
      assert_locked "orm", "0.5.0"
    end
  end

  def test_updated_lockfile_on_removed_dependencies
    metadata = {dependencies: {web: "~> 1.0.0"}}
    lock = {web: "1.0.0", orm: "0.5.0"}

    with_shard(metadata, lock) do
      run "shards install"

      assert_installed "web", "1.0.0"
      assert_locked "web", "1.0.0"

      refute_installed "orm", "0.5.0"
      refute_locked "orm", "0.5.0"
    end
  end

  def test_locks_commit_when_installing_git_refs
    metadata = {dependencies: {web: {git: git_url(:web), branch: "master"}}}

    with_shard(metadata) do
      run "shards install"
      assert_locked "web", git_commits(:web).first
    end
  end

  def test_production_doesnt_install_development_dependencies
    metadata = {
      dependencies:             {web: "*", orm: "*"},
      development_dependencies: {mock: "*"},
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
        orm: "*",
      },
    }
    lock = {web: "1.0.0"}

    with_shard(metadata, lock) do
      ex = assert_raises(FailedCommand) { run "shards install --production --no-color" }
      assert_match "Outdated shard.lock", ex.stdout
      assert_empty ex.stderr
    end
  end

  def test_doesnt_generate_lockfile_when_project_has_no_dependencies
    with_shard({name: "test"}) do
      run "shards install"

      refute File.exists?(File.join(application_path, "shard.lock")),
        "expected shard.lock to not have been generated"
    end
  end

  def test_runs_postinstall_script
    with_shard({dependencies: {post: "*"}}) do
      run "shards install"
      assert File.exists?(File.join(application_path, "lib", "post", "made.txt"))
    end
  end

  def test_prints_details_and_removes_dependency_when_postinstall_script_fails
    with_shard({dependencies: {fails: "*"}}) do
      ex = assert_raises(FailedCommand) { run "shards install --no-color" }
      assert_match "E: Failed make:\n", ex.stdout
      assert_match "test -n ''\n", ex.stdout
      refute Dir.exists?(File.join(application_path, "lib", "fails"))
    end
  end

  def test_runs_postinstall_with_transitive_dependencies
    with_shard({ dependencies: {transitive: "*"} }) do
      run "shards install"
      binary = File.join(application_path, "lib", "transitive", "version")
      assert File.exists?(binary)
      assert_equal "version @ 0.1.0\n", `#{binary}`
    end
  end

  def test_fails_when_shard_name_doesnt_match
    metadata = {
      dependencies: {
        typo: {git: git_url(:mock), version: "*"},
      },
    }
    with_shard(metadata) do
      ex = assert_raises(FailedCommand) { run "shards install --no-color" }
      assert_match "Error shard name (mock) doesn't match dependency name (typo)", ex.stdout
    end
  end

  def test_installs_executables_at_version
    metadata = {
      dependencies: {binary: "0.1.0"}
    }
    with_shard(metadata) { run("shards install --no-color") }

    foobar = File.join(application_path, "bin", "foobar")
    baz = File.join(application_path, "bin", "baz")
    foo = File.join(application_path, "bin", "foo")

    assert File.exists?(foobar), "Expected to have installed bin/foobar executable"
    assert File.exists?(baz), "Expected to have installed bin/baz executable"
    refute File.exists?(foo), "Expected not to have installed bin/foo executable"

    assert_equal "OK\n", `#{foobar}`
    assert_equal "KO\n", `#{baz}`
  end

  def test_installs_executables_at_refs
    metadata = {
      dependencies: {
        binary: {git: git_url(:binary), commit: git_commits(:binary)[-1]}
      },
    }
    with_shard(metadata) { run("shards install --no-color") }

    foobar = File.join(application_path, "bin", "foobar")
    baz = File.join(application_path, "bin", "baz")
    foo = File.join(application_path, "bin", "foo")

    assert File.exists?(foobar), "Expected to have installed bin/foobar executable"
    assert File.exists?(baz), "Expected to have installed bin/baz executable"
    refute File.exists?(foo), "Expected not to have installed bin/foo executable"
  end
end
