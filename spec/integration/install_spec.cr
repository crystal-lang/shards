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

  it "resolves intersection" do
    metadata = {dependencies: {web: ">= 1.1.0, < 2.0"}}
    with_shard(metadata) do
      run "shards install"
      assert_installed "web", "1.2.0"
    end
  end

  it "fails when spec is missing" do
    Dir.cd(application_path) do
      ex = expect_raises(FailedCommand) { run "shards install --no-color" }
      ex.stdout.should contain("Missing #{Shards::SPEC_FILENAME}")
      ex.stdout.should contain("Please run 'shards init'")
    end
  end

  it "reinstall if info file is missing" do
    metadata = {dependencies: {web: "*"}}
    with_shard(metadata) do
      run "shards install"
      File.delete "#{Shards::INSTALL_DIR}/.shards.info"
      File.touch "#{Shards::INSTALL_DIR}/web/foo.txt"
      run "shards install"
      File.exists?("#{Shards::INSTALL_DIR}/web/foo.txt").should be_false
      assert_installed "web", "2.1.0"
    end
  end

  it "reinstall if info file is missing (path resolver)" do
    metadata = {dependencies: {web: {path: rel_path(:web)}}}
    with_shard(metadata) do
      run "shards install"
      File.delete "#{Shards::INSTALL_DIR}/.shards.info"
      run "shards install"
      assert_installed "web", "2.1.0"
    end
  end

  it "deletes old .sha1 files" do
    metadata = {dependencies: {web: "*"}}
    with_shard(metadata) do
      Dir.mkdir_p(Shards::INSTALL_DIR)
      File.touch("#{Shards::INSTALL_DIR}/web.sha1")
      run "shards install"
      File.exists?("#{Shards::INSTALL_DIR}/web.sha1").should be_false
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

  it "install specific commit" do
    metadata = {dependencies: {"web": {git: git_url(:web), commit: git_commits(:web)[2]}}}
    with_shard(metadata) { run "shards install" }
    assert_installed "web", "1.2.0", git: git_commits(:web)[2]
  end

  it "install specific abbreviated commit" do
    metadata = {dependencies: {"web": {git: git_url(:web), commit: git_commits(:web)[2][0...5]}}}
    with_shard(metadata) { debug "shards install" }
    assert_installed "web", "1.2.0", git: git_commits(:web)[2]
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
    create_git_release "locked", "0.1.0"
    create_git_release "locked", "0.2.0", {dependencies: {pg: {git: git_url(:pg)}}}

    metadata = {
      dependencies: {
        "locked": {git: git_url(:locked), branch: "master"},
      },
    }
    lock = {
      "locked": "0.1.0+git.commit.#{git_commits(:locked).last}",
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

  it "updates locked commit when switching from locked version to branch" do
    metadata = {
      dependencies: {
        web: {git: git_url(:web), branch: "master"},
      },
    }
    lock = {web: "1.2.0"}
    expected_commit = git_commits(:web).first

    with_shard(metadata, lock) do
      run "shards install"
      assert_installed "web", "2.1.0", git: expected_commit
      assert_locked "web", "2.1.0+git.commit.#{expected_commit}"
    end
  end

  pending "updates locked commit when switching between branches (if locked commit is not reachable)"

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

  it "keeps installed version if possible when dependency source changed" do
    metadata = {dependencies: {awesome: {git: git_url(:forked_awesome)}}}
    lock = {awesome: "0.1.0"}

    with_shard(metadata, lock) do
      assert_locked "awesome", "0.1.0", source: {git: git_url(:awesome)}

      output = run "shards install --no-color"

      assert_locked "awesome", "0.1.0", source: {git: git_url(:forked_awesome)}
      assert_installed "awesome", "0.1.0", source: {git: git_url(:forked_awesome)}

      output.should contain("Ignoring source of \"awesome\" on shard.lock")
    end
  end

  it "keeps nested dependencies locked when main dependency source changed" do
    metadata = {dependencies: {awesome: {git: git_url(:forked_awesome)}}}
    lock = {awesome: "0.1.0", d: "0.1.0"}

    with_shard(metadata, lock) do
      assert_locked "awesome", "0.1.0", source: {git: git_url(:awesome)}
      assert_locked "d", "0.1.0", source: {git: git_url(:d)}

      output = run "shards install --no-color"

      assert_locked "awesome", "0.1.0", source: {git: git_url(:forked_awesome)}
      assert_locked "d", "0.1.0", source: {git: git_url(:d)}
      assert_installed "awesome", "0.1.0", source: {git: git_url(:forked_awesome)}
      assert_installed "d", "0.1.0", source: {git: git_url(:d)}

      output.should contain("Ignoring source of \"awesome\" on shard.lock")
    end
  end

  it "reinstall when resolver changes" do
    metadata = {dependencies: {web: {git: git_url(:web)}}}
    with_shard(metadata) do
      run "shards install"
      assert_locked "web", "2.1.0"
    end

    metadata = {dependencies: {web: {path: rel_path(:web)}}}
    with_shard(metadata) do
      run "shards install"
      assert_locked "web", "2.1.0", source: {path: rel_path(:web)}
      assert_installed "web", "2.1.0", source: {path: rel_path(:web)}
    end

    metadata = {dependencies: {web: {git: git_url(:web)}}}
    with_shard(metadata) do
      run "shards install"
      assert_locked "web", "2.1.0", source: {git: git_url(:web)}
      assert_installed "web", "2.1.0", source: {git: git_url(:web)}
    end
  end

  it "fails if shard.lock and shard.yml has different sources" do
    # The sources will not match, so the .lock is not valid regarding the specs
    metadata = {dependencies: {awesome: {git: git_url(:forked_awesome)}}}
    lock = {awesome: "0.1.0", d: "0.1.0"}

    with_shard(metadata, lock) do
      assert_locked "awesome", "0.1.0", source: {git: git_url(:awesome)}

      ex = expect_raises(FailedCommand) { run "shards install --production --no-color" }
      ex.stdout.should contain("Outdated shard.lock (awesome source changed)")
      ex.stderr.should be_empty
    end
  end

  it "fails if shard.lock and shard.yml has different sources with incompatible versions." do
    # User should use update command in this scenario
    # forked_awesome does not have a 0.3.0
    # awesome has 0.3.0
    metadata = {dependencies: {awesome: {git: git_url(:forked_awesome)}}}
    lock = {awesome: "0.3.0"}

    with_shard(metadata, lock) do
      assert_locked "awesome", "0.3.0", source: {git: git_url(:awesome)}

      ex = expect_raises(FailedCommand) { run "shards install --production --no-color" }
      ex.stdout.should contain("Maybe a commit, branch or file doesn't exist?")
      ex.stderr.should be_empty
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

  it "upgrade lock file from 1.0" do
    metadata = {dependencies: {web: "*"}}

    with_shard(metadata) do
      File.write "shard.lock", YAML.dump({
        version: "1.0",
        shards:  {web: {git: git_url(:web), commit: git_commits(:web).first}},
      })

      run "shards install"
      Shards::Lock.from_file("shard.lock").version.should eq(Shards::Lock::CURRENT_VERSION)
      assert_locked "web", "2.1.0", git: git_commits(:web).first
    end
  end

  it "production doesn't install development dependencies" do
    metadata = {
      dependencies:             {web: "*", orm: "*"},
      development_dependencies: {mock: "*"},
    }

    with_shard(metadata) do
      File.exists?(File.join(application_path, "shard.lock")).should be_false
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

  it "generates lockfile when project has no dependencies" do
    with_shard({name: "test"}) do
      run "shards install"

      lockfile = File.join(application_path, "shard.lock")
      File.exists?(lockfile).should be_true
      File.read(lockfile).should eq <<-YAML
        version: 2.0
        shards: {}

        YAML
    end
  end

  it "touches lockfile if no new dependencies are installed" do
    metadata = {dependencies: {d: "*", c: "*"}}

    with_shard(metadata) do
      run "shards install"
      File.touch "shard.lock", Time.utc(1901, 12, 14)
      mtime = File.info("shard.lock").modification_time
      run "shards install"
      File.info("shard.lock").modification_time.should be >= mtime
    end
  end

  it "updates lockfile on completely removed dependencies" do
    metadata = NamedTuple.new
    lock = {web: "1.0.0"}

    with_shard(metadata, lock) do
      run "shards install"

      refute_installed "web"
      refute_locked "web"
    end
  end

  it "runs postinstall script" do
    with_shard({dependencies: {post: "*"}}) do
      output = run "shards install --no-color"
      File.exists?(install_path("post", "made.txt")).should be_true
      output.should contain("Postinstall of post: make")
    end
  end

  {% if flag?(:win32) %}
    # Crystal bug in handling a failing subprocess
    pending "prints details and removes dependency when postinstall script fails"
  {% else %}
    it "prints details and removes dependency when postinstall script fails" do
      with_shard({dependencies: {fails: "*"}}) do
        ex = expect_raises(FailedCommand) { run "shards install --no-color" }
        ex.stdout.should contain("E: Failed postinstall of fails on make:\n")
        ex.stdout.should contain("test -n ''\n")
        Dir.exists?(install_path("fails")).should be_false
      end
    end
  {% end %}

  it "runs postinstall with transitive dependencies" do
    with_shard({dependencies: {transitive: "*"}}) do
      run "shards install"
      binary = install_path("transitive", Shards::Helpers.exe("version"))
      File.exists?(binary).should be_true
      `#{Process.quote(binary)}`.chomp.should eq("version @ 0.1.0")
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
    create_git_release "a", "0.1.0", {dependencies: {b: {git: git_path("b")}}}
    create_git_repository "b"
    create_git_release "b", "0.1.0", {dependencies: {a: {git: git_path("a")}}}

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

    foobar = File.join(application_path, "bin", Shards::Helpers.exe("foobar"))
    baz = File.join(application_path, "bin", Shards::Helpers.exe("baz"))
    foo = File.join(application_path, "bin", Shards::Helpers.exe("foo"))

    File.exists?(foobar).should be_true # "Expected to have installed bin/foobar executable"
    File.exists?(baz).should be_true    # "Expected to have installed bin/baz executable"
    File.exists?(foo).should be_false   # "Expected not to have installed bin/foo executable"

    `#{Process.quote(foobar)}`.should eq("OK")
    `#{Process.quote(baz)}`.should eq("KO")
  end

  it "installs executables at refs" do
    metadata = {
      dependencies: {
        binary: {git: git_url(:binary), commit: git_commits(:binary)[-1]},
      },
    }
    with_shard(metadata) { run("shards install --no-color") }

    foobar = File.join(application_path, "bin", Shards::Helpers.exe("foobar"))
    baz = File.join(application_path, "bin", Shards::Helpers.exe("baz"))
    foo = File.join(application_path, "bin", Shards::Helpers.exe("foo"))

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
      stdout = run "shards install --no-color", env: {"CRYSTAL_VERSION" => "0.34.0"}
      assert_installed "noshardyml", "0.1.0"
      stdout.should contain(%(W: Shard "noshardyml" version (0.1.0) doesn't have a shard.yml file))
    end
  end

  it "shows error when branch does not exist" do
    metadata = {dependencies: {web: {git: git_url(:web), branch: "foo"}}}
    with_shard(metadata) do
      ex = expect_raises(FailedCommand) { run "shards install --no-color" }
      ex.stdout.should contain(%(E: Could not find branch foo for shard "web" in the repository #{git_url(:web)}))
    end
  end

  it "shows error when tag does not exist" do
    metadata = {dependencies: {web: {git: git_url(:web), tag: "foo"}}}
    with_shard(metadata) do
      ex = expect_raises(FailedCommand) { run "shards install --no-color" }
      ex.stdout.should contain(%(E: Could not find tag foo for shard "web" in the repository #{git_url(:web)}))
    end
  end

  it "shows error when commit does not exist" do
    metadata = {dependencies: {web: {git: git_url(:web), commit: "f8f67cc67d6bd3479811825a49a16260a8c767a3"}}}
    with_shard(metadata) do
      ex = expect_raises(FailedCommand) { run "shards install --no-color" }
      ex.stdout.should contain(%(E: Could not find commit f8f67cc67d6bd3479811825a49a16260a8c767a3 for shard "web" in the repository #{git_url(:web)}))
    end
  end

  it "shows error when installing by ref and shard.yml doesn't exist" do
    metadata = {dependencies: {noshardyml: {git: git_url(:noshardyml), tag: "v0.1.0"}}}
    with_shard(metadata) do
      ex = expect_raises(FailedCommand) { run "shards install --no-color" }
      ex.stdout.should contain(%(E: No shard.yml was found for shard "noshardyml" at commit #{git_commits(:noshardyml)[1]}))
    end
  end

  it "install version according to current crystal version" do
    metadata = {dependencies: {incompatible: "*"}}
    with_shard(metadata) do
      run "shards install", env: {"CRYSTAL_VERSION" => "0.3.0"}
      assert_installed "incompatible", "0.2.0"
    end
  end

  it "install version according to current crystal version (major-minor only)" do
    metadata = {dependencies: {incompatible: "*"}}
    with_shard(metadata) do
      run "shards install", env: {"CRYSTAL_VERSION" => "0.4.1"}
      assert_installed "incompatible", "0.3.0"
    end
  end

  it "install version ignoring current crystal version if --ignore-crystal-version" do
    metadata = {dependencies: {incompatible: "*"}}
    with_shard(metadata) do
      stdout = run "shards install --ignore-crystal-version --no-color", env: {"CRYSTAL_VERSION" => "0.3.0"}
      assert_installed "incompatible", "1.0.0"
      stdout.should contain(%(Shard "incompatible" may be incompatible with Crystal 0.3.0))
    end
  end

  it "install version ignoring current crystal version if --ignore-crystal-version (via SHARDS_OPTS)" do
    metadata = {dependencies: {incompatible: "*"}}
    with_shard(metadata) do
      run "shards install", env: {"CRYSTAL_VERSION" => "0.3.0", "SHARDS_OPTS" => "--ignore-crystal-version"}
      assert_installed "incompatible", "1.0.0"
    end
  end

  it "doesn't match crystal version for major upgrade" do
    metadata = {dependencies: {incompatible: "*"}}
    with_shard(metadata) do
      ex = expect_raises(FailedCommand) { run "shards install --no-color", env: {"CRYSTAL_VERSION" => "2.0.0"} }
      refute_installed "incompatible"
    end
  end

  it "does match crystal prerelease" do
    metadata = {dependencies: {incompatible: "*"}}
    with_shard(metadata) do
      run "shards install", env: {"CRYSTAL_VERSION" => "1.0.0-pre1"}
      assert_installed "incompatible", "1.0.0"
    end
  end

  it "warn about unneeded --ignore-crystal-version" do
    metadata = {dependencies: {incompatible: "*"}}
    with_shard(metadata) do
      stdout = run "shards install --ignore-crystal-version --no-color", env: {"CRYSTAL_VERSION" => "1.1.0"}
      assert_installed "incompatible", "1.0.0"
      stdout.should contain(%(Using --ignore-crystal-version was not needed. All shards are already compatible with Crystal 1.1.0))
    end
  end

  it "fails on conflicting sources" do
    metadata = {dependencies: {
      intermediate: "*",
      awesome:      {git: git_url(:forked_awesome)},
    }}
    with_shard(metadata) do
      ex = expect_raises(FailedCommand) { run "shards install --no-color" }
      ex.stdout.should contain("Error shard name (awesome) has ambiguous sources")
    end
  end

  it "can override to use local path" do
    metadata = {dependencies: {
      intermediate: "*",
    }}
    override = {dependencies: {
      awesome: {path: git_path(:forked_awesome)},
    }}
    with_shard(metadata, nil, override) do
      run "shards install"

      assert_installed "awesome", "0.2.0", source: {path: git_path(:forked_awesome)}
      assert_locked "awesome", "0.2.0", source: {path: git_path(:forked_awesome)}
    end
  end

  it "can override to use forked git repository branch" do
    metadata = {dependencies: {
      intermediate: "*",
    }}
    override = {dependencies: {
      awesome: {git: git_url(:forked_awesome), branch: "feature/super"},
    }}
    expected_commit = git_commits(:forked_awesome).first

    with_shard(metadata, nil, override) do
      run "shards install"

      assert_installed "awesome", "0.2.0+git.commit.#{expected_commit}", source: {git: git_url(:forked_awesome)}
      assert_locked "awesome", "0.2.0+git.commit.#{expected_commit}", source: {git: git_url(:forked_awesome)}
    end
  end

  it "updates to override with branch if lock is not up to date in main dependency" do
    metadata = {dependencies: {
      awesome: "*",
    }}
    lock = {awesome: "0.1.0", d: "0.1.0"}
    override = {dependencies: {
      awesome: {git: git_url(:forked_awesome), branch: "feature/super"},
    }}
    expected_commit = git_commits(:forked_awesome).first

    with_shard(metadata, lock, override) do
      run "shards install"

      assert_installed "awesome", "0.2.0+git.commit.#{expected_commit}", source: {git: git_url(:forked_awesome)}
      assert_locked "awesome", "0.2.0+git.commit.#{expected_commit}", source: {git: git_url(:forked_awesome)}

      # nested dependencies are unlocked version
      assert_installed "d", "0.2.0"
      assert_locked "d", "0.2.0"
    end
  end

  it "updates to override with branch if lock is not up to date in nested dependency" do
    metadata = {dependencies: {
      intermediate: "*",
    }}
    lock = {intermediate: "0.1.0", awesome: "0.1.0", d: "0.1.0"}
    override = {dependencies: {
      awesome: {git: git_url(:forked_awesome), branch: "feature/super"},
    }}
    expected_commit = git_commits(:forked_awesome).first

    with_shard(metadata, lock, override) do
      run "shards install"

      assert_installed "awesome", "0.2.0+git.commit.#{expected_commit}", source: {git: git_url(:forked_awesome)}
      assert_locked "awesome", "0.2.0+git.commit.#{expected_commit}", source: {git: git_url(:forked_awesome)}

      # nested dependencies are unlocked version
      assert_installed "d", "0.2.0"
      assert_locked "d", "0.2.0"
    end
  end

  it "updates to override with version if lock is not up to date in main dependency" do
    metadata = {dependencies: {
      awesome: "*",
    }}
    lock = {awesome: "0.1.0", d: "0.1.0"}
    override = {dependencies: {
      awesome: {git: git_url(:forked_awesome), version: "0.2.0"},
    }}

    with_shard(metadata, lock, override) do
      run "shards install"

      assert_installed "awesome", "0.2.0", source: {git: git_url(:forked_awesome)}
      assert_locked "awesome", "0.2.0", source: {git: git_url(:forked_awesome)}
    end
  end

  it "updates to override with version if lock is not up to date in nested dependency" do
    metadata = {dependencies: {
      intermediate: "*",
    }}
    lock = {intermediate: "0.1.0", awesome: "0.1.0", d: "0.1.0"}
    override = {dependencies: {
      awesome: {git: git_url(:forked_awesome), version: "0.2.0"},
    }}

    with_shard(metadata, lock, override) do
      run "shards install"

      assert_installed "awesome", "0.2.0", source: {git: git_url(:forked_awesome)}
      assert_locked "awesome", "0.2.0", source: {git: git_url(:forked_awesome)}
    end
  end

  it "keeps nested dependency lock if it's also a main dependency" do
    metadata = {dependencies: {
      awesome: "*",
      d:       "*",
    }}
    lock = {awesome: "0.1.0", d: "0.1.0"}
    override = {dependencies: {
      awesome: {git: git_url(:forked_awesome), branch: "feature/super"},
    }}
    expected_commit = git_commits(:forked_awesome).first

    with_shard(metadata, lock, override) do
      run "shards install"

      assert_installed "awesome", "0.2.0+git.commit.#{expected_commit}", source: {git: git_url(:forked_awesome)}
      assert_locked "awesome", "0.2.0+git.commit.#{expected_commit}", source: {git: git_url(:forked_awesome)}

      # keep nested dependencies locked version
      assert_installed "d", "0.1.0"
      assert_locked "d", "0.1.0"
    end
  end

  it "keeps override with branch in locked commit in main dependency" do
    # There is one commit more in this forked_awesome feature/super branch
    locked_commit = git_commits(:forked_awesome)[1]
    metadata = {dependencies: {
      awesome: "*",
    }}
    lock = {
      awesome: {version: "0.2.0+git.commit.#{locked_commit}", git: git_url(:forked_awesome)},
      d:       "0.1.0",
    }
    override = {dependencies: {
      awesome: {git: git_url(:forked_awesome), branch: "feature/super"},
    }}

    with_shard(metadata, lock, override) do
      run "shards install"

      assert_installed "awesome", "0.2.0+git.commit.#{locked_commit}", source: {git: git_url(:forked_awesome)}
      assert_locked "awesome", "0.2.0+git.commit.#{locked_commit}", source: {git: git_url(:forked_awesome)}
    end
  end

  it "keeps override with branch in locked commit in nested dependency" do
    # There is one commit more in this forked_awesome feature/super branch
    locked_commit = git_commits(:forked_awesome)[1]
    metadata = {dependencies: {
      intermediate: "*",
    }}
    lock = {
      intermediate: "0.1.0",
      awesome:      {version: "0.2.0+git.commit.#{locked_commit}", git: git_url(:forked_awesome)},
      d:            "0.1.0",
    }
    override = {dependencies: {
      awesome: {git: git_url(:forked_awesome), branch: "feature/super"},
    }}

    with_shard(metadata, lock, override) do
      run "shards install"

      assert_installed "awesome", "0.2.0+git.commit.#{locked_commit}", source: {git: git_url(:forked_awesome)}
      assert_locked "awesome", "0.2.0+git.commit.#{locked_commit}", source: {git: git_url(:forked_awesome)}
    end
  end

  it "fails if lock is not up to date with override in main dependency in production" do
    metadata = {dependencies: {
      awesome: "*",
    }}
    lock = {awesome: "0.1.0", d: "0.1.0"}
    override = {dependencies: {
      awesome: {git: git_url(:forked_awesome), branch: "feature/super"},
    }}
    expected_commit = git_commits(:forked_awesome).first

    with_shard(metadata, lock, override) do
      ex = expect_raises(FailedCommand) { run "shards install --no-color --production" }
      ex.stdout.should contain("Outdated shard.lock")
      ex.stderr.should be_empty
      refute_installed "awesome"
    end
  end

  it "fails if lock is not up to date with override in nested dependency in production" do
    metadata = {dependencies: {
      intermediate: "*",
    }}
    lock = {intermediate: "0.1.0", awesome: "0.1.0", d: "0.1.0"}
    override = {dependencies: {
      awesome: {git: git_url(:forked_awesome), branch: "feature/super"},
    }}
    expected_commit = git_commits(:forked_awesome).first

    with_shard(metadata, lock, override) do
      ex = expect_raises(FailedCommand) { run "shards install --no-color --production" }
      ex.stdout.should contain("Outdated shard.lock")
      ex.stderr.should be_empty
      refute_installed "awesome"
    end
  end

  it "uses override relative file specified in SHARDS_OVERRIDE env var" do
    metadata = {dependencies: {
      intermediate: "*",
    }}
    ignored_override = {dependencies: {
      awesome: {path: git_path(:forked_awesome)},
    }}
    ci_override = {dependencies: {
      awesome: {git: git_url(:forked_awesome)},
    }}
    with_shard(metadata, nil, ignored_override) do
      File.write "shard.ci.yml", to_override_yaml(ci_override)

      run "shards install", env: {"SHARDS_OVERRIDE" => "shard.ci.yml"}

      assert_installed "awesome", "0.2.0", source: {git: git_url(:forked_awesome)}
      assert_locked "awesome", "0.2.0", source: {git: git_url(:forked_awesome)}
    end
  end

  it "fails if file specified in SHARDS_OVERRIDE env var does not exist" do
    metadata = {dependencies: {
      intermediate: "*",
    }}
    ignored_override = {dependencies: {
      awesome: {path: git_path(:forked_awesome)},
    }}
    with_shard(metadata, nil, ignored_override) do
      ex = expect_raises(FailedCommand) do
        run "shards install --no-color", env: {"SHARDS_OVERRIDE" => "shard.missing.yml"}
      end
      ex.stdout.should contain("Missing shard.missing.yml")
    end
  end

  it "warn about unneeded --ignore-crystal-version" do
    metadata = {dependencies: {incompatible: "*"}}
    with_shard(metadata) do
      stdout = run "shards install --ignore-crystal-version --no-color", env: {"CRYSTAL_VERSION" => "1.1.0"}
      assert_installed "incompatible", "1.0.0"
      stdout.should contain(%(Using --ignore-crystal-version was not needed. All shards are already compatible with Crystal 1.1.0))
    end
  end

  describe "mtime" do
    it "mtime lib > shard.lock > shard.yml" do
      metadata = {dependencies: {
        web: "*",
      }}
      with_shard(metadata) do
        run "shards install"
        File.info("shard.lock").modification_time.should be <= File.info("lib").modification_time
        File.info("shard.yml").modification_time.should be <= File.info("shard.lock").modification_time
      end
    end

    it "mtime shard.lock > shard.yml even when unmodified" do
      metadata = {dependencies: {
        web: "*",
      }}
      with_shard(metadata) do
        run "shards install"
        File.touch("shard.yml")
        run "shards install"
        File.info("shard.yml").modification_time.should be <= File.info("shard.lock").modification_time
      end
    end
  end
end
