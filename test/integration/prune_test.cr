require "../integration_helper"

class PruneCommandTest < Minitest::Test
  def setup
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

  def test_removes_unused_dependencies
    Dir.cd(application_path) { run "shards prune" }
    assert_equal ["web"], installed_dependencies
    refute File.exists?(File.join(application_path, "lib", "orm.sha1"))
  end

  def test_removes_directories
    Dir.mkdir(File.join(application_path, "lib", "test"))
    Dir.cd(application_path) { run "shards prune" }
    assert_equal ["web"], installed_dependencies
  end

  def test_wont_remove_files
    File.write(File.join(application_path, "lib", ".keep_hidden"), "")
    File.write(File.join(application_path, "lib", "keep_not_hidden"), "")
    Dir.cd(application_path) { run "shards prune" }
    assert_equal [".keep_hidden", "keep_not_hidden", "web"], installed_dependencies.sort
  end

  private def installed_dependencies
    Dir.glob(File.join(application_path, "lib", "*"), match_hidden: true).map { |path| File.basename(path) }
  end
end
