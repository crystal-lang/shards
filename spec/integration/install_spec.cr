require "./spec_helper"

describe "install" do
  it "installs dependencies" do
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

  it "fails when spec is missing" do
    Dir.cd(application_path) do
      ex = expect_raises(FailedCommand) { run "shards install --no-color" }
      ex.stdout.should contain("Missing #{Shards::SPEC_FILENAME}")
      ex.stdout.should contain("Please run 'shards init'")
    end
  end

  it "won't fail if info file is missing (backward compatibility)" do
    metadata = {dependencies: {web: "*"}}
    with_shard(metadata) do
      run "shards install"
      File.delete("lib/.shards.info")
      run "shards install"
    end
  end

  it "won't install prerelease version" do
    metadata = {
      dependencies: {unstable: "*"},
    }
    with_shard(metadata) do
      run "shards install"
      assert_installed "unstable", "0.2.0"
      assert_locked "unstable", "0.2.0"
    end
  end

  it "installs specified prerelease version" do
    metadata = {
      dependencies: {unstable: "0.3.0.alpha"},
    }
    with_shard(metadata) do
      run "shards install"
      assert_installed "unstable", "0.3.0.alpha"
      assert_locked "unstable", "0.3.0.alpha"
    end
  end

  it "installs prerelease version at refs" do
    metadata = {
      dependencies: {
        unstable: {git: git_url(:unstable), branch: "master"},
      },
    }
    with_shard(metadata) do
      run "shards install"
      assert_installed "unstable", "0.3.0.beta", git: git_commits(:unstable).first
    end
  end

  it "installs dependencies at locked version" do
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

  it "always installs locked versions" do
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

  it "resolves dependency at head when no version tags" do
    metadata = {dependencies: {"missing": "*"}}
    with_shard(metadata) { run "shards install" }
    assert_installed "missing", "0.1.0", git: git_commits(:missing).first
  end

  it "installs dependency at locked commit when refs is a branch" do
    metadata = {
      dependencies: {
        web: {git: git_url(:web), branch: "master"},
      },
    }
    lock = {web: "1.2.0+git.commit.#{git_commits(:web)[-5]}"}

    with_shard(metadata, lock) do
      run "shards install"
      assert_installed "web", "1.2.0", git: git_commits(:web)[-5]
    end
  end

  it "installs dependency at locked commit when refs is a version tag" do
    metadata = {
      dependencies: {web: {git: git_url(:web), tag: "v1.1.1"}},
    }
    lock = {web: "1.1.1+git.commit.#{git_commits(:web)[-3]}"}

    with_shard(metadata, lock) do
      run "shards install"
      assert_installed "web", "1.1.1", git: git_commits(:web)[-3]
    end
  end

  it "resolves dependency spec at locked commit" do
    create_git_repository "locked"
    create_git_release "locked", "0.1.0", "name: locked\nversion: 0.1.0\n"
    create_git_release "locked", "0.2.0", "name: locked\nversion: 0.2.0\ndependencies:\n  pg:\n    git: #{git_path("pg")}\n"

    metadata = {
      dependencies: {
        "locked": {git: git_path(:"locked"), branch: "master"},
      },
    }
    lock = {
      "locked": "0.1.0+git.commit.#{git_commits(:"locked").last}",
    }
    with_shard(metadata, lock) { run "shards install" }

    assert_installed "locked", "0.1.0", git: git_commits(:locked).last
    refute_installed "pg"
  end

  it "updates locked commit" do
    metadata = {
      dependencies: {web: {git: git_url(:web), branch: "master"}},
    }

    with_shard(metadata, {web: "1.2.0+git.commit.#{git_commits(:web)[-5]}"}) do
      run "shards install"
      assert_installed "web", "1.2.0", git: git_commits(:web)[-5]
    end

    with_shard(metadata, {web: "2.1.0+git.commit.#{git_commits(:web)[0]}"}) do
      run "shards install"
      assert_installed "web", "2.1.0", git: git_commits(:web)[0]
    end
  end

  it "fails to install when dependency requirement changed in production" do
    metadata = {dependencies: {web: "2.0.0"}}
    lock = {web: "1.0.0"}

    with_shard(metadata, lock) do
      ex = expect_raises(FailedCommand) { run "shards install --no-color --production" }
      ex.stdout.should contain("Outdated shard.lock")
      ex.stderr.should be_empty
      refute_installed "web"
    end
  end

  it "fails to install when dependency requirement (commit) changed in production" do
    metadata = {dependencies: {inprogress: {git: git_url(:inprogress), commit: git_commits(:inprogress)[1]}}}
    lock = {inprogress: "0.1.0+git.commit.#{git_commits(:inprogress).first}"}

    with_shard(metadata, lock) do
      ex = expect_raises(FailedCommand) { run "shards install --no-color --production" }
      ex.stdout.should contain("Outdated shard.lock")
      refute_installed "inprogress"
    end
  end

  it "updates when dependency requirement changed" do
    metadata = {dependencies: {web: "2.0.0"}}
    lock = {web: "1.0.0"}

    with_shard(metadata, lock) do
      run "shards install"

      assert_installed "web", "2.0.0"
      assert_locked "web", "2.0.0"
    end
  end

  it "install subdependency of new dependency respecting lock" do
    metadata = {dependencies: {c: "*", d: "*"}}
    lock = {d: "0.1.0"}

    with_shard(metadata, lock) do
      run "shards install"

      assert_installed "c", "0.1.0"
      assert_installed "d", "0.1.0"
    end
  end

  it "installs and updates lockfile for added dependencies" do
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

  it "updated lockfile on removed dependencies" do
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

  it "locks commit when installing git refs" do
    metadata = {dependencies: {web: {git: git_url(:web), branch: "master"}}}

    with_shard(metadata) do
      run "shards install"
      assert_locked "web", "2.1.0", git: git_commits(:web).first
    end
  end

  it "production doesn't install development dependencies" do
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
      File.exists?(File.join(application_path, "shard.lock")).should be_false
    end
  end

  it "production doesn't install new dependencies" do
    metadata = {
      dependencies: {
        web: "~> 1.0.0",
        orm: "*",
      },
    }
    lock = {web: "1.0.0"}

    with_shard(metadata, lock) do
      ex = expect_raises(FailedCommand) { run "shards install --production --no-color" }
      ex.stdout.should contain("Outdated shard.lock")
      ex.stderr.should be_empty
    end
  end

  it "install in production mode" do
    metadata = {dependencies: {web: "*"}}
    lock = {web: "1.0.0"}

    with_shard(metadata, lock) do
      run "shards install --production"
      assert_installed "web", "1.0.0"
    end
  end

  it "install in production mode with locked commit" do
    metadata = {dependencies: {web: "*"}}
    web_version = "2.1.0+git.commit.#{git_commits(:web).first}"
    lock = {web: web_version}

    with_shard(metadata, lock) do
      run "shards install --production"
      assert_installed "web", "2.1.0", git: git_commits(:web).first
    end
  end

  it "install in production mode with locked commit by a previous shards version" do
    metadata = {dependencies: {web: "*"}}

    with_shard(metadata) do
      File.write "shard.lock", {version: "1.0", shards: {web: {git: git_url(:web), commit: git_commits(:web).first}}}
      run "shards install --production"
      assert_installed "web", "2.1.0", git: git_commits(:web).first
    end
  end

  it "doesn't generate lockfile when project has no dependencies" do
    with_shard({name: "test"}) do
      run "shards install"

      File.exists?(File.join(application_path, "shard.lock")).should be_false
    end
  end

  it "doesn't overwrite lockfile if no new dependencies are installed" do
    metadata = {dependencies: {d: "*", c: "*"}}

    with_shard(metadata) do
      run "shards install"
      File.touch "shard.lock", Time.utc(1900, 1, 1)
      mtime = File.info("shard.lock").modification_time
      run "shards install"
      File.info("shard.lock").modification_time.should eq(mtime)
    end
  end

  it "runs postinstall script" do
    with_shard({dependencies: {post: "*"}}) do
      output = run "shards install --no-color"
      File.exists?(File.join(application_path, "lib", "post", "made.txt")).should be_true
      output.should contain("Postinstall of post: make")
    end
  end

  it "prints details and removes dependency when postinstall script fails" do
    with_shard({dependencies: {fails: "*"}}) do
      ex = expect_raises(FailedCommand) { run "shards install --no-color" }
      ex.stdout.should contain("E: Failed postinstall of fails on make:\n")
      ex.stdout.should contain("test -n ''\n")
      Dir.exists?(File.join(application_path, "lib", "fails")).should be_false
    end
  end

  it "runs postinstall with transitive dependencies" do
    with_shard({dependencies: {transitive: "*"}}) do
      run "shards install"
      binary = File.join(application_path, "lib", "transitive", "version")
      File.exists?(binary).should be_true
      `#{binary}`.should eq("version @ 0.1.0\n")
    end
  end

  it "runs install and postinstall in reverse topological order" do
    with_shard({dependencies: {transitive_2: "*"}}) do
      output = run "shards install --no-color"
      install_lines = output.lines.select /^\w: (Installing|Postinstall)/
      install_lines[0].should match(/Installing version /)
      install_lines[1].should match(/Installing transitive /)
      install_lines[2].should match(/Postinstall of transitive:/)
      install_lines[3].should match(/Installing transitive_2 /)
      install_lines[4].should match(/Postinstall of transitive_2:/)
    end
  end

  it "fails with circular dependencies" do
    create_git_repository "a"
    create_git_release "a", "0.1.0", "name: a\nversion: 0.1.0\ndependencies:\n  b:\n    git: #{git_path("b")}"
    create_git_repository "b"
    create_git_release "b", "0.1.0", "name: b\nversion: 0.1.0\ndependencies:\n  a:\n    git: #{git_path("a")}"

    with_shard({dependencies: {a: "*"}}) do
      ex = expect_raises(FailedCommand) { run "shards install --no-color" }
      ex.stdout.should contain("There is a circular dependency between a and b")
    end
  end

  it "fails when shard name doesn't match" do
    metadata = {
      dependencies: {
        typo: {git: git_url(:mock), version: "*"},
      },
    }
    with_shard(metadata) do
      ex = expect_raises(FailedCommand) { run "shards install --no-color" }
      ex.stdout.should contain("Error shard name (mock) doesn't match dependency name (typo)")
    end
  end

  it "warns when shard.yml version doesn't match git tag" do
    metadata = {
      dependencies: {
        version_mismatch: {git: git_url(:version_mismatch), version: "0.2.0"},
      },
    }
    with_shard(metadata) do
      stdout = run "shards install --no-color"
      stdout.should contain("W: Shard \"version_mismatch\" version (0.1.0) doesn't match tag version (0.2.0)")
      assert_installed "version_mismatch"
    end
  end

  it "doesn't warn when version mismatch is fixed" do
    metadata = {
      dependencies: {
        version_mismatch: {git: git_url(:version_mismatch), version: "0.2.1"},
      },
    }
    with_shard(metadata) do
      stdout = run "shards install --no-color"
      stdout.should_not contain("doesn't match tag version")
      assert_installed "version_mismatch", "0.2.1"
    end
  end

  it "test install old with version when shard was renamed" do
    metadata = {
      dependencies: {
        old_name: {git: git_url(:renamed), version: "0.1.0"},
      },
    }
    with_shard(metadata) do
      run "shards install"
      assert_installed "old_name", "0.1.0"
    end
  end

  it "test install new when shard was renamed" do
    metadata = {
      dependencies: {
        new_name: {git: git_url(:renamed)},
      },
    }
    with_shard(metadata) do
      run "shards install"
      assert_installed "new_name", "0.2.0"
    end
  end

  it "fail install old version when shard was renamed" do
    metadata = {
      dependencies: {
        new_name: {git: git_url(:renamed), version: "0.1.0"},
      },
    }
    with_shard(metadata) do
      ex = expect_raises(FailedCommand) { run "shards install --no-color" }
      ex.stdout.should contain("Error shard name (old_name) doesn't match dependency name (new_name)")
    end
  end

  it "fail install new version when shard was renamed" do
    metadata = {
      dependencies: {
        old_name: {git: git_url(:renamed), version: "0.2.0"},
      },
    }
    with_shard(metadata) do
      ex = expect_raises(FailedCommand) { run "shards install --no-color" }
      ex.stdout.should contain("Error shard name (new_name) doesn't match dependency name (old_name)")
    end
  end

  it "install untagged version when shard was renamed" do
    metadata = {
      dependencies: {
        another_name: {git: git_url(:renamed), branch: "master"},
      },
    }
    with_shard(metadata) do
      run "shards install"
      assert_installed "another_name", "0.3.0", git: git_commits(:renamed).first
    end
  end

  it "installs executables at version" do
    metadata = {
      dependencies: {binary: "0.1.0"},
    }
    with_shard(metadata) { run("shards install --no-color") }

    foobar = File.join(application_path, "bin", "foobar")
    baz = File.join(application_path, "bin", "baz")
    foo = File.join(application_path, "bin", "foo")

    File.exists?(foobar).should be_true # "Expected to have installed bin/foobar executable"
    File.exists?(baz).should be_true    # "Expected to have installed bin/baz executable"
    File.exists?(foo).should be_false   # "Expected not to have installed bin/foo executable"

    `#{foobar}`.should eq("OK\n")
    `#{baz}`.should eq("KO\n")
  end

  it "installs executables at refs" do
    metadata = {
      dependencies: {
        binary: {git: git_url(:binary), commit: git_commits(:binary)[-1]},
      },
    }
    with_shard(metadata) { run("shards install --no-color") }

    foobar = File.join(application_path, "bin", "foobar")
    baz = File.join(application_path, "bin", "baz")
    foo = File.join(application_path, "bin", "foo")

    File.exists?(foobar).should be_true # "Expected to have installed bin/foobar executable"
    File.exists?(baz).should be_true    # "Expected to have installed bin/baz executable"
    File.exists?(foo).should be_false   # "Expected not to have installed bin/foo executable"
  end

  it "shows conflict message" do
    metadata = {
      dependencies: {
        c: "~> 0.1.0",
        d: ">= 0.2.0",
      },
    }

    with_shard(metadata) do
      ex = expect_raises(FailedCommand) { run "shards install --no-color" }
      ex.stdout.should contain <<-ERROR
        E: Unable to satisfy the following requirements:

        - `d (>= 0.2.0)` required by `shard.yml`
        - `d (0.1.0)` required by `c 0.1.0`
        ERROR
    end
  end

  it "installs dependency with shard.yml created in latest version" do
    metadata = {dependencies: {noshardyml: "*"}}
    with_shard(metadata) do
      run "shards install"
      assert_installed "noshardyml", "0.2.0"
    end
  end

  it "shows missing shard.yml in debug info" do
    metadata = {dependencies: {noshardyml: "*"}}
    with_shard(metadata) do
      stdout = run "shards install --no-color -v"
      assert_installed "noshardyml", "0.2.0"
      stdout.should contain(%(D: Missing "shard.yml" for "noshardyml" at tag v0.1.0))
    end
  end

  it "install dependency with no shard.yml and show warning" do
    metadata = {dependencies: {noshardyml: "0.1.0"}}
    with_shard(metadata) do
      stdout = run "shards install --no-color"
      assert_installed "noshardyml", "0.1.0"
      stdout.should contain(%(W: Shard "noshardyml" version (0.1.0) doesn't have a shard.yml file))
    end
  end

  it "shows error when branch does not exist" do
    metadata = {dependencies: {web: {git: git_url(:web), branch: "foo"}}}
    with_shard(metadata) do
      ex = expect_raises(FailedCommand) { run "shards install --no-color" }
      ex.stdout.should contain(%(E: Could not find branch foo in the repository #{git_url(:web)} for shard "web"))
    end
  end

  it "shows error when tag does not exist" do
    metadata = {dependencies: {web: {git: git_url(:web), tag: "foo"}}}
    with_shard(metadata) do
      ex = expect_raises(FailedCommand) { run "shards install --no-color" }
      ex.stdout.should contain(%(E: Could not find tag foo in the repository #{git_url(:web)} for shard "web"))
    end
  end

  it "shows error when commit does not exist" do
    metadata = {dependencies: {web: {git: git_url(:web), commit: "f8f67cc67d6bd3479811825a49a16260a8c767a3"}}}
    with_shard(metadata) do
      ex = expect_raises(FailedCommand) { run "shards install --no-color" }
      ex.stdout.should contain(%(E: Could not find commit f8f67cc67d6bd3479811825a49a16260a8c767a3 in the repository #{git_url(:web)} for shard "web"))
    end
  end

  it "shows error when installing by ref and shard.yml doesn't exist" do
    metadata = {dependencies: {noshardyml: {git: git_url(:noshardyml), tag: "v0.1.0"}}}
    with_shard(metadata) do
      ex = expect_raises(FailedCommand) { run "shards install --no-color" }
      ex.stdout.should contain(%(E: No shard.yml was found for shard "noshardyml" at commit #{git_commits(:noshardyml)[1]}))
    end
  end
end
