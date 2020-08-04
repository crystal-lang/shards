require "./spec_helper"

describe "check" do
  it "succeeds when all dependencies are installed" do
    metadata = {
      dependencies:             {web: "*", orm: "*"},
      development_dependencies: {mock: "*"},
    }
    with_shard(metadata) do
      run "shards install"
      run "shards check"
    end
  end

  it "succeeds when dependencies match loose requirements" do
    with_shard({dependencies: {web: "1.2.0"}}) do
      run "shards install"
    end

    with_shard({dependencies: {web: "~> 1.1"}}) do
      run "shards check"
    end
  end

  it "fails without lockfile" do
    with_shard({dependencies: {web: "*"}}) do
      ex = expect_raises(FailedCommand) { run "shards check --no-color" }
      ex.stdout.should contain("Missing #{Shards::LOCK_FILENAME}")
      ex.stderr.should be_empty
    end
  end

  it "succeeds without dependencies and lockfile" do
    with_shard({name: "no_dependencies"}) do
      run "shards check --no-color"
    end
  end

  it "fails when dependencies are missing" do
    with_shard({dependencies: {web: "*"}}) do
      run "shards install"
    end

    metadata = {
      dependencies:             {web: "*", orm: "*"},
      development_dependencies: {mock: "*"},
    }
    with_shard(metadata) do
      ex = expect_raises(FailedCommand) { run "shards check --no-color" }
      ex.stdout.should contain("Dependencies aren't satisfied")
      ex.stderr.should be_empty
    end
  end

  it "fails when wrong versions are installed" do
    with_shard({dependencies: {web: "1.0.0"}}) do
      run "shards install"
    end

    with_shard({dependencies: {web: "2.0.0"}}) do
      ex = expect_raises(FailedCommand) { run "shards check --no-color" }
      ex.stdout.should contain("Dependencies aren't satisfied")
      ex.stderr.should be_empty
    end
  end

  it "succeeds when shard.yml version doesn't match git tag" do
    metadata = {
      dependencies: {
        version_mismatch: {git: git_url(:version_mismatch), version: "0.2.0"},
      },
    }
    with_shard(metadata) do
      run "shards install"
      run "shards check"
    end
  end

  it "fails when another source was installed" do
    with_shard({dependencies: {awesome: "0.1.0"}}) do
      run "shards install"
    end

    with_shard({dependencies: {awesome: {git: git_url(:forked_awesome)}}}) do
      ex = expect_raises(FailedCommand) { run "shards check --no-color" }
      ex.stdout.should contain("Dependencies aren't satisfied")
      ex.stderr.should be_empty
    end
  end
end
