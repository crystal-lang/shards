require "./spec_helper"

private def installed_dependencies
  Dir.children(install_path).reject!(".shards.info")
end

describe "prune" do
  before_each do
    metadata = {
      dependencies:             {web: "*", orm: {git: git_url(:orm), branch: "master"}},
      development_dependencies: {mock: "*"},
    }
    with_shard(metadata) { run "shards install" }

    metadata = {
      dependencies: {web: "*"},
    }
    with_shard(metadata) { run "shards update" }
  end

  it "removes unused dependencies" do
    Dir.cd(application_path) { run "shards prune" }
    installed_dependencies.should eq(["web"])
    Shards::Info.new(install_path).installed.keys.should eq(["web"])
  end

  it "removes directories" do
    Dir.mkdir(install_path("test"))
    Dir.cd(application_path) { run "shards prune" }
    installed_dependencies.should eq(["web"])
  end

  it "won't remove files" do
    File.write(install_path(".keep_hidden"), "")
    File.write(install_path("keep_not_hidden"), "")
    Dir.cd(application_path) { run "shards prune" }
    installed_dependencies.sort.should eq([".keep_hidden", "keep_not_hidden", "web"])
  end

  it "should not fail if the install directory does not exist" do
    FileUtils.rm_rf(install_path)
    Dir.cd(application_path) { run "shards prune" }
  end
end
