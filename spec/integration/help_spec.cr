require "./spec_helper"

describe "--help" do
  metadata = {
    version: "1.0.0",
    dependencies: {
      mock: { git: git_path("mock") }
    }
  }

  it "prints help and doesn't invoke the command" do
    [
      "shards --help",
      "shards --local --help",
      "shards update --help",
    ].each do |command|
      with_shard(metadata) do
        output = run command

        # it printed the help message
        output.should contain("Commands:")
        output.should contain("General options:")

        # it didn't run the command (or default command)
        output.should_not contain("Resolving dependencies")
      end
    end
  end
end
