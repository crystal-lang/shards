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

  it "generates lockfile for empty dependencies" do
    metadata = {dependencies: {} of Symbol => String}
    with_shard(metadata) do
      run "shards update"
      path = File.join(application_path, "shard.lock")
      File.exists?(path).should be_true
      File.read(path).should eq <<-YAML
        version: 2.0
        shards: {}

        YAML
    end
  end

  it "runs postinstall with transitive dependencies" do
    with_shard({dependencies: {transitive: "*"}}, {transitive: "0.1.0"}) do
      run "shards update"
      binary = install_path("transitive", Shards::Helpers.exe("version"))
      File.exists?(binary).should be_true
      `#{Process.quote(binary)}`.chomp.should eq("version @ 0.1.0")
    end
  end

  it "skips postinstall with transitive dependencies" do
    with_shard({dependencies: {transitive: "*"}}, {transitive: "0.1.0"}) do
      output = run "shards update --no-color --skip-postinstall"
      binary = install_path("transitive", Shards::Helpers.exe("version"))
      File.exists?(binary).should be_false
      output.should contain("Postinstall of transitive: crystal build src/version.cr (skipped)")
    end
  end

  it "installs new executables" do
    metadata = {dependencies: {binary: "0.2.0"}}
    lock = {binary: "0.1.0"}
    with_shard(metadata, lock) { run("shards update --no-color") }

    foobar = File.join(application_path, "bin", Shards::Helpers.exe("foobar"))
    baz = File.join(application_path, "bin", Shards::Helpers.exe("baz"))
    foo = File.join(application_path, "bin", Shards::Helpers.exe("foo"))

    File.exists?(foobar).should be_true # "Expected to have installed bin/foobar executable"
    File.exists?(baz).should be_true    # "Expected to have installed bin/baz executable"
    File.exists?(foo).should be_true    # "Expected to have installed bin/foo executable"

    `#{Process.quote(foobar)}`.should eq("OK")
    `#{Process.quote(baz)}`.should eq("KO")
    `#{Process.quote(foo)}`.should eq("FOO")
  end

  it "skips installing new executables" do
    metadata = {dependencies: {binary: "0.2.0"}}
    lock = {binary: "0.1.0"}
    with_shard(metadata, lock) { run("shards update --no-color --skip-executables") }

    foobar = File.join(application_path, "bin", Shards::Helpers.exe("foobar"))
    baz = File.join(application_path, "bin", Shards::Helpers.exe("baz"))
    foo = File.join(application_path, "bin", Shards::Helpers.exe("foo"))

    File.exists?(foobar).should be_false
    File.exists?(baz).should be_false
    File.exists?(foo).should be_false
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

  it "can update to forked branch after lock" do
    metadata = {dependencies: {awesome: {git: git_url(:forked_awesome), branch: "feature/super"}}}
    lock = {awesome: "0.1.0", d: "0.1.0"}

    with_shard(metadata, lock) do
      assert_locked "awesome", "0.1.0", source: {git: git_url(:awesome)}

      run "shards update"

      assert_locked "awesome", "0.2.0", git: git_commits(:forked_awesome).first
      assert_installed "awesome", "0.2.0", git: git_commits(:forked_awesome).first
    end
  end

  it "can update top dependency with override branch" do
    metadata = {dependencies: {
      awesome: "*",
    }}
    lock = {awesome: "0.1.0"}
    override = {dependencies: {
      awesome: {git: git_url(:forked_awesome), branch: "feature/super"},
    }}
    expected_commit = git_commits(:forked_awesome).first

    with_shard(metadata, lock, override) do
      run "shards update"

      assert_installed "awesome", "0.2.0+git.commit.#{expected_commit}", source: {git: git_url(:forked_awesome)}
      assert_locked "awesome", "0.2.0+git.commit.#{expected_commit}", source: {git: git_url(:forked_awesome)}
    end
  end

  it "can update top dependency override version" do
    metadata = {dependencies: {
      awesome: "*",
    }}
    lock = {awesome: "0.1.0"}
    override = {dependencies: {
      awesome: {git: git_url(:forked_awesome), version: "0.1.0"},
    }}

    with_shard(metadata, lock, override) do
      run "shards update"

      assert_installed "awesome", "0.1.0", source: {git: git_url(:forked_awesome)}
      assert_locked "awesome", "0.1.0", source: {git: git_url(:forked_awesome)}
    end
  end

  it "can update to nested override branch" do
    metadata = {dependencies: {
      intermediate: "*",
    }}
    lock = {intermediate: "0.1.0", awesome: "0.1.0"}
    override = {dependencies: {
      awesome: {git: git_url(:forked_awesome), branch: "feature/super"},
    }}
    expected_commit = git_commits(:forked_awesome).first

    with_shard(metadata, lock, override) do
      run "shards update"

      assert_installed "awesome", "0.2.0+git.commit.#{expected_commit}", source: {git: git_url(:forked_awesome)}
      assert_locked "awesome", "0.2.0+git.commit.#{expected_commit}", source: {git: git_url(:forked_awesome)}
    end
  end

  it "can update to nested override version" do
    metadata = {dependencies: {
      intermediate: "*",
    }}
    lock = {intermediate: "0.1.0", awesome: "0.1.0"}
    override = {dependencies: {
      awesome: {git: git_url(:forked_awesome), version: "0.1.0"},
    }}

    with_shard(metadata, lock, override) do
      run "shards update"

      assert_installed "awesome", "0.1.0", source: {git: git_url(:forked_awesome)}
      assert_locked "awesome", "0.1.0", source: {git: git_url(:forked_awesome)}
    end
  end

  it "update to nested latest override if no version" do
    metadata = {dependencies: {
      intermediate: "*",
    }}
    lock = {intermediate: "0.1.0", awesome: "0.1.0"}
    override = {dependencies: {
      awesome: {git: git_url(:forked_awesome)}, # latest version of forked_awesome is 0.2.0
    }}

    with_shard(metadata, lock, override) do
      run "shards update"

      assert_installed "awesome", "0.2.0", source: {git: git_url(:forked_awesome)}
      assert_locked "awesome", "0.2.0", source: {git: git_url(:forked_awesome)}
    end
  end

  it "updating all with override does unlock nested" do
    metadata = {dependencies: {
      intermediate: "*",
    }}
    lock = {intermediate: "0.1.0", awesome: "0.1.0", d: "0.1.0"}
    override = {dependencies: {
      awesome: {git: git_url(:forked_awesome)}, # latest version of forked_awesome is 0.2.0
    }}

    with_shard(metadata, lock, override) do
      run "shards update"

      assert_installed "d", "0.2.0"
      assert_locked "d", "0.2.0"
    end
  end

  describe "mtime" do
    it "mtime lib > shard.lock > shard.yml" do
      metadata = {dependencies: {
        web: "*",
      }}
      with_shard(metadata) do
        run "shards update"
        File.info("shard.lock").modification_time.should be <= File.info("lib").modification_time
        File.info("shard.yml").modification_time.should be <= File.info("shard.lock").modification_time
        run "shards update"
        File.info("shard.lock").modification_time.should be <= File.info("lib").modification_time
        File.info("shard.yml").modification_time.should be <= File.info("shard.lock").modification_time
      end
    end

    it "mtime shard.lock > shard.yml even when unmodified" do
      metadata = {dependencies: {
        web: "*",
      }}
      with_shard(metadata) do
        run "shards update"
        File.touch("shard.yml")
        run "shards update"
        File.info("shard.lock").modification_time.should be <= File.info("lib").modification_time
        File.info("shard.yml").modification_time.should be <= File.info("shard.lock").modification_time
      end
    end
  end

  it "updates lockfile when there are no dependencies" do
    with_shard({name: "empty"}) do
      run "shards update"
      mtime = File.info("shard.lock").modification_time
      run "shards update"
      File.info("shard.lock").modification_time.should be >= mtime
      Shards::Lock.from_file("shard.lock").version.should eq(Shards::Lock::CURRENT_VERSION)
    end
  end

  it "creates ./lib/ when there are no dependencies" do
    with_shard({name: "empty"}) do
      File.exists?("./lib/").should be_false
      run "shards update"
      File.directory?("./lib/").should be_true
    end
  end
end
