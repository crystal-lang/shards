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
end
