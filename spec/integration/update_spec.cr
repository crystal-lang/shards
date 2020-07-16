require "./spec_helper"

describe "update" do
  it "installs dependencies" do
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

  it "updates locked dependencies" do
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

  it "unlocks subdependency" do
    metadata = {dependencies: {c: "*"}}
    lock = {c: "0.1.0", d: "0.1.0"}

    with_shard(metadata, lock) do
      run "shards update c"

      assert_installed "c", "0.2.0"
      assert_installed "d", "0.2.0"
    end
  end

  it "updates specified dependencies" do
    metadata = {dependencies: {web: "*", orm: "*", optional: "*"}}
    lock = {web: "1.0.0", orm: "0.4.0", optional: "0.2.0"}

    with_shard(metadata, lock) do
      run "shards update orm optional"

      # keeps unspecified dependencies:
      assert_installed "web", "1.0.0"
      assert_locked "web", "1.0.0"

      # updates specified dependencies:
      assert_installed "orm", "0.5.0"
      assert_locked "orm", "0.5.0"
      assert_installed "optional", "0.2.2"
      assert_locked "optional", "0.2.2"

      # installs additional dependencies:
      assert_installed "pg", "0.2.1"
      assert_locked "pg", "0.2.1"
    end
  end

  it "won't install prerelease version" do
    metadata = {dependencies: {unstable: "*"}}
    lock = {unstable: "0.1.0"}

    with_shard(metadata, lock) do
      run "shards update"
      assert_installed "unstable", "0.2.0"
      assert_locked "unstable", "0.2.0"
    end
  end

  it "installs specified prerelease version" do
    metadata = {dependencies: {unstable: "~> 0.3.0.alpha"}}
    lock = {unstable: "0.3.0.alpha"}

    with_shard(metadata, lock) do
      run "shards update"
      assert_installed "unstable", "0.3.0.beta"
      assert_locked "unstable", "0.3.0.beta"
    end
  end

  it "updates locked specified prerelease" do
    metadata = {dependencies: {unstable: "~> 0.3.0.alpha"}}
    lock = {unstable: "0.3.0.alpha"}

    with_shard(metadata, lock) do
      run "shards update"
      assert_installed "unstable", "0.3.0.beta"
      assert_locked "unstable", "0.3.0.beta"
    end
  end

  it "updates from prerelease to release with approximate operator" do
    metadata = {dependencies: {preview: "~> 0.3.0.a"}}
    lock = {preview: "0.3.0.alpha"}

    with_shard(metadata, lock) do
      run "shards update"
      assert_installed "preview", "0.3.0"
      assert_locked "preview", "0.3.0"
    end
  end

  # TODO: detect version, and prefer release (0.3.0) over further prereleases (?)
  it "updates to latest prerelease with >= operator" do
    metadata = {dependencies: {preview: ">= 0.3.0.a"}}
    lock = {preview: "0.3.0.a"}

    with_shard(metadata, lock) do
      run "shards update"
      assert_installed "preview", "0.4.0.a"
      assert_locked "preview", "0.4.0.a"
    end
  end

  it "updates locked commit" do
    metadata = {
      dependencies: {web: {git: git_url(:web), branch: "master"}},
    }
    lock = {web: git_commits(:web)[-5]}

    with_shard(metadata, lock) do
      run "shards update"
      assert_installed "web", "2.1.0", git: git_commits(:web).first
      assert_locked "web", "2.1.0", git: git_commits(:web).first
    end
  end

  it "installs new dependencies" do
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

  it "removes dependencies" do
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

  it "finds then updates new compatible version" do
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

  it "won't generate lockfile for empty dependencies" do
    metadata = {dependencies: {} of Symbol => String}
    with_shard(metadata) do
      path = File.join(application_path, "shard.lock")
      File.exists?(path).should be_false
    end
  end

  it "runs postinstall with transitive dependencies" do
    with_shard({dependencies: {transitive: "*"}}, {transitive: "0.1.0"}) do
      run "shards update"
      binary = install_path("transitive", "version")
      File.exists?(binary).should be_true
      `#{binary}`.should eq("version @ 0.1.0\n")
    end
  end

  it "installs new executables" do
    metadata = {dependencies: {binary: "0.2.0"}}
    lock = {binary: "0.1.0"}
    with_shard(metadata, lock) { run("shards update --no-color") }

    foobar = File.join(application_path, "bin", "foobar")
    baz = File.join(application_path, "bin", "baz")
    foo = File.join(application_path, "bin", "foo")

    File.exists?(foobar).should be_true # "Expected to have installed bin/foobar executable"
    File.exists?(baz).should be_true    # "Expected to have installed bin/baz executable"
    File.exists?(foo).should be_true    # "Expected to have installed bin/foo executable"

    `#{foobar}`.should eq("OK\n")
    `#{baz}`.should eq("KO\n")
    `#{foo}`.should eq("FOO\n")
  end

  it "doesn't update local cache" do
    metadata = {
      dependencies: {local_cache: "*"},
    }

    with_shard(metadata) do
      # error: dependency isn't in local cache
      ex = expect_raises(FailedCommand) { run("shards install --local --no-color") }
      ex.stdout.should contain(%(E: Missing repository cache for "local_cache".))
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

  it "updates when dependency source changed" do
    metadata = {dependencies: {web: {path: git_path(:web)}}}
    lock = {web: "2.1.0"}

    with_shard(metadata, lock) do
      assert_locked "web", "2.1.0", source: {git: git_url(:web)}

      run "shards update"

      assert_locked "web", "2.1.0", source: {path: git_path(:web)}
      assert_installed "web", "2.1.0", source: {path: git_path(:web)}
    end
  end

  it "keeping installed version requires constraint in shard.yml" do
    # forked_awesome has 0.2.0
    metadata = {dependencies: {awesome: {git: git_url(:forked_awesome), version: "~> 0.1.0"}}}
    lock = {awesome: "0.1.0"}

    with_shard(metadata, lock) do
      assert_locked "awesome", "0.1.0", source: {git: git_url(:awesome)}

      run "shards update"

      assert_locked "awesome", "0.1.0", source: {git: git_url(:forked_awesome)}
      assert_installed "awesome", "0.1.0", source: {git: git_url(:forked_awesome)}
    end
  end

  it "bumps nested dependencies locked when main dependency source changed" do
    metadata = {dependencies: {awesome: {git: git_url(:forked_awesome)}}}
    lock = {awesome: "0.1.0", d: "0.1.0"}

    with_shard(metadata, lock) do
      assert_locked "awesome", "0.1.0", source: {git: git_url(:awesome)}
      assert_locked "d", "0.1.0", source: {git: git_url(:d)}

      # d is not a top dependency, so it is bumped since it's required only by awesome
      run "shards update awesome"

      assert_locked "awesome", "0.2.0", source: {git: git_url(:forked_awesome)}
      assert_locked "d", "0.2.0", source: {git: git_url(:d)}
      assert_installed "awesome", "0.2.0", source: {git: git_url(:forked_awesome)}
      assert_installed "d", "0.2.0", source: {git: git_url(:d)}
    end
  end
end
