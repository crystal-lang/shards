require "./spec_helper"

describe "version" do
  it "version default directory" do
    metadata = {
      version: "1.33.7",
    }
    with_shard(metadata) do
      stdout = run "shards version"
      stdout.should contain("1.33.7")
    end
  end

  it "version within directory" do
    metadata = {
      version: "0.0.42",
    }
    with_shard(metadata) do
      inner_path = File.join(application_path, "lib/test")
      Dir.mkdir_p inner_path

      outer_path = File.expand_path("..", application_path)
      Dir.cd(outer_path) do
        stdout = run "shards version #{inner_path}"
        stdout.should contain("0.0.42")
      end
    end
  end

  it "fails version" do
    expect_raises(FailedCommand) do
      root = File.expand_path("/", Dir.current)
      run "shards version #{root}"
    end
  end
end
