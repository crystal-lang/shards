require "./spec_helper"

private def installed_dependencies
  Dir.glob(File.join(application_path, "lib", "*"), match_hidden: true)
    .map { |path| File.basename(path) }
    .reject { |file| file =~ /\.version$/ }
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
    File.exists?(File.join(application_path, "lib", "orm.sha1")).should be_false
  end

  it "removes directories" do
    Dir.mkdir(File.join(application_path, "lib", "test"))
    Dir.cd(application_path) { run "shards prune" }
    installed_dependencies.should eq(["web"])
  end

  it "won't remove files" do
    File.write(File.join(application_path, "lib", ".keep_hidden"), "")
    File.write(File.join(application_path, "lib", "keep_not_hidden"), "")
    Dir.cd(application_path) { run "shards prune" }
    installed_dependencies.sort.should eq([".keep_hidden", "keep_not_hidden", "web"])
  end
end
