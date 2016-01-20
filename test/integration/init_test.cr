require "../integration_helper"

class InitCommandTest < Minitest::Test
  def test_creates_shard_yml
    Dir.cd(application_path) do
      run "shards init"
      assert File.exists?(File.join(application_path, Shards::SPEC_FILENAME))
      spec = Shards::Spec.from_file(shard_path)
      assert_equal "integration", spec.name
      assert_equal "0.1.0", spec.version
    end
  end

  def test_wont_overwrite_shard_yml
    Dir.cd(application_path) do
      File.write(shard_path, "")
      ex = assert_raises(FailedCommand) { run "shards init --no-color" }
      assert_match "#{ Shards::SPEC_FILENAME } already exists", ex.stdout
      assert_empty File.read(shard_path)
    end
  end

  private def shard_path
    File.join(application_path, Shards::SPEC_FILENAME)
  end
end
