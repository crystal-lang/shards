require "./spec_helper"

describe "list" do
  it "lists all dependencies" do
    metadata = {
      dependencies:             {web: "*", orm: "*"},
      development_dependencies: {mock: "*"},
    }
    with_shard(metadata) do
      run "shards install"
      stdout = run "shards list"

      stdout.should contain("web (2.1.0)")
      stdout.should contain("orm (0.5.0)")
      stdout.should contain("pg (0.2.1)")
      stdout.should contain("mock (0.1.0)")
      stdout.should contain("shoulda (0.1.0)")
    end
  end

  it "production doesn't list development dependencies" do
    metadata = {
      dependencies:             {web: "*", orm: "*"},
      development_dependencies: {mock: "*"},
    }
    with_shard(metadata) do
      run "shards install --production"
      stdout = run "shards list --production"
      stdout.should contain("web (2.1.0)")
      stdout.should contain("orm (0.5.0)")
      stdout.should contain("pg (0.2.1)")
      stdout.should_not contain("mock (0.1.0)")
      stdout.should_not contain("shoulda (0.1.0)")
    end
  end

  it "lists tree all dependencies" do
    metadata = {
      dependencies:             {web: "*", orm: "*"},
      development_dependencies: {mock: "*"},
    }
    with_shard(metadata) do
      run "shards install"
      stdout = run "shards list --tree"
      stdout.should contain("  * web (2.1.0)")
      stdout.should contain("  * orm (0.5.0)")
      stdout.should contain("    * pg (0.2.1)")
      stdout.should contain("  * mock (0.1.0)")
      stdout.should contain("    * shoulda (0.1.0)")
    end
  end

  it "show error when dependencies are not installed" do
    metadata = {
      dependencies:             {web: "*", orm: "*"},
      development_dependencies: {mock: "*"},
    }
    with_shard(metadata) do
      ex = expect_raises(FailedCommand) { run "shards list --no-color" }
      ex.stdout.should contain("Dependencies aren't satisfied. Install them with 'shards install'")
    end
  end

  it "show previous installed dependency when source has changed" do
    with_shard({dependencies: {awesome: "0.1.0"}}) do
      run "shards install"
    end

    with_shard({dependencies: {awesome: {version: "0.2.0", git: git_url(:forked_awesome)}}}) do
      stdout = run "shards list --tree"
      stdout.should contain("  * awesome (0.1.0)")
      stdout.should contain("    * d (0.2.0)")
    end
  end

  it "show previous installed dependency when override is added" do
    metadata = {dependencies: {awesome: "0.1.0"}}

    with_shard(metadata) do
      run "shards install"
    end

    override = {dependencies: {awesome: "0.2.0"}}

    with_shard(metadata, nil, override) do
      stdout = run "shards list --tree"
      stdout.should contain("  * awesome (0.1.0)")
      stdout.should contain("    * d (0.2.0)")
    end
  end
end
