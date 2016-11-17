require "../integration_helper"

class PruneCommandTest < Minitest::Test
  def setup
    metadata = {
      dependencies: { web: "*", orm: "*", },
      development_dependencies: { mock: "*" },
    }
    with_shard(metadata) { run "shards install" }

    metadata = {
      dependencies: { web: "*" }
    }
    with_shard(metadata) { run "shards update" }
  end

  def test_removes_unused_dependencies
    Dir.cd(application_path) { run "shards prune" }
    assert_equal ["web"], installed_dependencies
  end

  def test_removes_directories
    Dir.mkdir(File.join(application_path, "lib", "test"))
    Dir.cd(application_path) { run "shards prune" }
    assert_equal ["web"], installed_dependencies
  end

  def test_wont_remove_files
    File.write(File.join(application_path, "lib", ".keep"), "")
    Dir.cd(application_path) { run "shards prune" }
    assert_equal [".keep", "web"], installed_dependencies.sort
  end

  private def installed_dependencies
    Dir[File.join(application_path, "lib", "*")].map { |path| File.basename(path) }
  end
end
