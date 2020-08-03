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
end
