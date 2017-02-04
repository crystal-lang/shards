require "../integration_helper"

class VersionCommandTest < Minitest::Test
  def test_version_default_directory
    metadata = {
      version: "1.33.7",
    }
    with_shard(metadata) do
      stdout = run "shards version", capture: true
      assert_match "1.33.7", stdout
    end
  end

  def test_version_within_directory
    metadata = {
      version: "0.0.42",
    }
    with_shard(metadata) do
      inner_path = File.join(application_path, "lib/test")
      Dir.mkdir_p inner_path

      outer_path = File.expand_path("..", application_path)
      Dir.cd(outer_path) do
        stdout = run "shards version #{inner_path}", capture: true
        assert_match "0.0.42", stdout
      end
    end
  end

  def test_fails_version
    ex = assert_raises(FailedCommand) do
      root = File.expand_path("/", Dir.current)
      run "shards version #{root}"
    end
  end
end
