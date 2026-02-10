require "./spec_helper"

private def shard_path
  File.join(application_path, Shards::SPEC_FILENAME)
end

describe "init" do
  it "creates shard.yml" do
    Dir.cd(application_path) do
      capture %w[shards init]
      File.exists?(File.join(application_path, Shards::SPEC_FILENAME)).should be_true
      spec = Shards::Spec.from_file(shard_path)
      spec.name.should eq("integration")
      spec.version.should eq(version "0.1.0")
    end
  end

  it "won't overwrite shard.yml" do
    Dir.cd(application_path) do
      File.write(shard_path, "")
      ex = expect_raises(FailedCommand) { capture %w[shards init --no-color] }
      ex.stdout.should contain("#{Shards::SPEC_FILENAME} already exists")
      File.read(shard_path).should be_empty
    end
  end
end
