require "./spec_helper"

describe "outdated" do
  it "up to date" do
    with_shard({dependencies: {web: "*"}}) do
      run "shards install"

      stdout = run "shards outdated --no-color"
      stdout.should contain("I: Dependencies are up to date!")
    end
  end

  it "not latest version" do
    with_shard({dependencies: {orm: "*"}}, {orm: "0.3.1"}) do
      run "shards install"

      stdout = run "shards outdated --no-color"
      stdout.should contain("W: Outdated dependencies:")
      stdout.should contain("  * orm (installed: 0.3.1, available: 0.5.0)")
    end
  end

  it "no releases" do
    commit = git_commits("missing").first
    with_shard({dependencies: {missing: "*"}}, {missing: "0.1.0+git.commit.#{commit}"}) do
      run "shards install"

      stdout = run "shards outdated --no-color"
      # FIXME: This should actually report dependencies are up to date (#446)
      stdout.should contain("W: Outdated dependencies:")
      stdout.should contain("  * missing (installed: 0.1.0 at #{commit[0..6]})")
    end
  end

  it "available version matching pessimistic operator" do
    with_shard({dependencies: {orm: "~> 0.3.0"}}, {orm: "0.3.1"}) do
      run "shards install"

      stdout = run "shards outdated --no-color"
      stdout.should contain("W: Outdated dependencies:")
      stdout.should contain("  * orm (installed: 0.3.1, available: 0.3.2, latest: 0.5.0)")
    end
  end

  it "reports new prerelease" do
    with_shard({dependencies: {unstable: "0.3.0.alpha"}}) do
      run "shards install"
    end
    with_shard({dependencies: {unstable: "~> 0.3.0.alpha"}}) do
      stdout = run "shards outdated --no-color"
      stdout.should contain("W: Outdated dependencies:")
      stdout.should contain("  * unstable (installed: 0.3.0.alpha, available: 0.3.0.beta)")
    end
  end

  it "won't report prereleases by default" do
    with_shard({dependencies: {preview: "*"}}, {preview: "0.2.0"}) do
      run "shards install"

      stdout = run "shards outdated --no-color"
      stdout.should contain("W: Outdated dependencies:")
      stdout.should contain("  * preview (installed: 0.2.0, available: 0.3.0)")
    end
  end

  it "reports prereleases when asked" do
    with_shard({dependencies: {preview: "*"}}, {preview: "0.2.0"}) do
      run "shards install"

      stdout = run "shards outdated --pre --no-color"
      stdout.should contain("W: Outdated dependencies:")
      stdout.should contain("  * preview (installed: 0.2.0, available: 0.4.0.a)")
    end
  end

  it "fails when source has changed" do
    with_shard({dependencies: {awesome: "0.1.0"}}) do
      run "shards install"
    end

    with_shard({dependencies: {awesome: {git: git_url(:forked_awesome)}}}) do
      ex = expect_raises(FailedCommand) { run "shards outdated --no-color" }
      ex.stdout.should contain("Outdated shard.lock (awesome source changed)")
    end
  end

  it "fails when requirements would require an update" do
    with_shard({dependencies: {awesome: "0.1.0"}}) do
      run "shards install"
    end

    with_shard({dependencies: {awesome: "0.2.0"}}) do
      ex = expect_raises(FailedCommand) { run "shards outdated --no-color" }
      ex.stdout.should contain("Outdated shard.lock (awesome requirements changed)")
    end
  end

  it "fails when requirements would require an update due to override" do
    metadata = {dependencies: {awesome: "0.1.0"}}

    with_shard(metadata) do
      run "shards install"
    end

    override = {dependencies: {awesome: "0.2.0"}}

    with_shard(metadata, nil, override) do
      ex = expect_raises(FailedCommand) { run "shards outdated --no-color" }
      ex.stdout.should contain("Outdated shard.lock (awesome requirements changed)")
    end
  end

  it "not latest version in override (same source)" do
    metadata = {dependencies: {awesome: "0.1.0"}}
    lock = {awesome: "0.1.0"}
    override = {dependencies: {awesome: "*"}}

    with_shard(metadata, lock, override) do
      run "shards install"

      stdout = run "shards outdated --no-color"
      stdout.should contain("W: Outdated dependencies:")
      stdout.should contain("  * awesome (installed: 0.1.0, available: 0.3.0)")
    end
  end

  it "not latest version in override (different source)" do
    metadata = {dependencies: {awesome: "0.1.0"}}
    lock = {awesome: {version: "0.1.0", git: git_url(:forked_awesome)}}
    override = {dependencies: {awesome: {git: git_url(:forked_awesome)}}}

    with_shard(metadata, lock, override) do
      run "shards install"

      stdout = run "shards outdated --no-color"
      stdout.should contain("W: Outdated dependencies:")
      stdout.should contain("  * awesome (installed: 0.1.0, available: 0.2.0)")
    end
  end

  it "up to date in override" do
    metadata = {dependencies: {awesome: "0.1.0"}}
    lock = {awesome: {version: "0.2.0", git: git_url(:forked_awesome)}}
    override = {dependencies: {awesome: {git: git_url(:forked_awesome)}}}

    with_shard(metadata, lock, override) do
      run "shards install"

      stdout = run "shards outdated --no-color"
      stdout.should contain("I: Dependencies are up to date!")
    end
  end

  describe "non-release" do
    describe "without relases" do
      it "latest any" do
        with_shard({dependencies: {missing: "*"}}, {missing: "0.1.0+git.commit.#{git_commits("missing").first}"}) do
          run "shards install"

          stdout = run "shards outdated --no-color"
          stdout.should contain("I: Dependencies are up to date!")
        end
      end

      it "latest branch" do
        with_shard({dependencies: {missing: {git: git_url("missing"), branch: "master"}}}, {missing: "0.1.0+git.commit.#{git_commits("missing").first}"}) do
          run "shards install"

          stdout = run "shards outdated --no-color"
          stdout.should contain("I: Dependencies are up to date!")
        end
      end

      it "latest commit" do
        with_shard({dependencies: {missing: {git: git_url("missing"), commit: git_commits("missing").first}}}, {missing: "0.1.0+git.commit.#{git_commits("missing").first}"}) do
          run "shards install"

          stdout = run "shards outdated --no-color"
          stdout.should contain("I: Dependencies are up to date!")
        end
      end

      it "outdated any" do
        commits = git_commits("inprogress")
        with_shard({dependencies: {inprogress: "*"}}, {inprogress: "0.1.0+git.commit.#{commits[1]}"}) do
          run "shards install"

          stdout = run "shards outdated --no-color"
          stdout.should contain("W: Outdated dependencies:")
          stdout.should contain("  * inprogress (installed: 0.1.0 at #{commits[1][0..6]}, available: 0.1.0 at #{commits.first[0..6]})")
        end
      end

      it "outdated branch" do
        commits = git_commits("inprogress")
        with_shard({dependencies: {inprogress: {git: git_url("inprogress"), branch: "master"}}}, {inprogress: "0.1.0+git.commit.#{commits[1]}"}) do
          run "shards install"

          stdout = run "shards outdated --no-color"
          stdout.should contain("W: Outdated dependencies:")
          stdout.should contain("  * inprogress (installed: 0.1.0 at #{commits[1][0..6]}, available: 0.1.0 at #{commits.first[0..6]})")
        end
      end

      it "outdated commit" do
        commits = git_commits("inprogress")
        with_shard({dependencies: {inprogress: {git: git_url("inprogress"), commit: commits[1]}}}, {inprogress: "0.1.0+git.commit.#{commits[1]}"}) do
          run "shards install"

          stdout = run "shards outdated --no-color"
          stdout.should contain("W: Outdated dependencies:")
          stdout.should contain("  * inprogress (installed: 0.1.0 at #{commits[1][0..6]}")
          # TODO: commit
          # stdout.should contain("  * inprogress (installed: 0.1.0 at #{commits[1][0..6]}, available: 0.1.0 at #{commits.first[0..6]})")
        end
      end
    end

    describe "with previous releases" do
      it "outdated any" do
        commits = git_commits("heading")
        with_shard({dependencies: {heading: "*"}}, {heading: "0.1.0+git.commit.#{commits[1]}"}) do
          run "shards install"

          stdout = run "shards outdated --no-color"
          stdout.should contain("W: Outdated dependencies:")
          stdout.should contain("  * heading (installed: 0.1.0 at #{commits[1][0..6]}, available: 0.1.0)")
          # TODO: stdout.should contain("  * heading (installed: 0.1.0 at #{commits[1][0..6]}, available: 0.1.0 at #{commits.first[0..6]})")
        end
      end

      it "latest any" do
        commits = git_commits("heading")
        with_shard({dependencies: {heading: "*"}}, {heading: "0.1.0+git.commit.#{commits.first}"}) do
          run "shards install"

          stdout = run "shards outdated --no-color"
          stdout.should contain("I: Dependencies are up to date!")
        end
      end

      it "latest branch" do
        commits = git_commits("heading")
        with_shard({dependencies: {heading: {git: git_url("heading"), branch: "master"}}}, {heading: "0.1.0+git.commit.#{commits.first}"}) do
          run "shards install"

          stdout = run "shards outdated --no-color"
          stdout.should contain("I: Dependencies are up to date!")
        end
      end
    end

    it "outdated any with new release" do
      commits = git_commits("release_hist")
      with_shard({dependencies: {release_hist: "*"}}, {release_hist: "0.1.0+git.commit.#{commits[1]}"}) do
        run "shards install"

        stdout = run "shards outdated --no-color"
        stdout.should contain("W: Outdated dependencies:")
        stdout.should contain("  * release_hist (installed: 0.1.0 at #{commits[1][0..6]}, available: 0.2.0)")
      end
    end

    it "outdated branch without new release" do
      installed_commit = git_commits("branched", "feature")[1]
      branch_head = git_commits("branched", "feature").first
      with_shard({dependencies: {branched: {git: git_url("branched"), branch: "feature"}}}, {branched: "0.1.0+git.commit.#{installed_commit}"}) do
        run "shards install"

        stdout = run "shards outdated --no-color"
        stdout.should contain("W: Outdated dependencies:")
        stdout.should contain("  * branched (installed: 0.1.0 at #{installed_commit[0..6]}, available: 0.1.0 at #{branch_head[0..6]}, latest: 0.2.0)")
      end
    end

    it "latest branch with release on HEAD" do
      branch_head = git_commits("branched", "feature").first
      with_shard({dependencies: {branched: {git: git_url("branched"), branch: "feature"}}}, {branched: "0.1.0+git.commit.#{branch_head}"}) do
        run "shards install"

        stdout = run "shards outdated --no-color"
        stdout.should contain("W: Outdated dependencies:")
        stdout.should contain("  * branched (installed: 0.1.0 at #{branch_head[0..6]}, latest: 0.2.0)")
      end
    end
  end
end
