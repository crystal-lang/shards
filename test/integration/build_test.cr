require "../integration_helper"

class BuildCommandTest < Minitest::Test

  def test_succeeds_for_specified_target
    metadata = {
      targets: { mock: { main: "mock.cr" } }
    }
    
    with_shard(metadata) do
      Dir.cd(application_path) do
        File.open "mock.cr", "w"
        run "shards build mock"
        assert File.exists?(File.join(application_path, "bin", "mock"))
      end
    end
  end

  def test_succeeds_for_all_targets
    metadata = {
      targets: { mock1: { main: "mock1.cr" },
                 mock2: { main: "mock2.cr" } }
    }
    
    with_shard(metadata) do
      Dir.cd(application_path) do
        File.open "mock1.cr", "w"
        File.open "mock2.cr", "w"
        run "shards build"
        assert File.exists?(File.join(application_path, "bin", "mock1"))
        assert File.exists?(File.join(application_path, "bin", "mock2"))
      end
    end
  end

  def test_succeeds_for_multiple_targets
    metadata = {
      targets: { mock1: { main: "mock1.cr" },
                 mock2: { main: "mock2.cr" },
                 mock3: { main: "mock3.cr" } }
    }

    with_shard(metadata) do
      Dir.cd(application_path) do
        File.open "mock1.cr", "w"
        File.open "mock2.cr", "w"
        File.open "mock3.cr", "w"
        run "shards build mock1 mock2"
        assert File.exists?(File.join(application_path, "bin", "mock1"))
        assert File.exists?(File.join(application_path, "bin", "mock2"))
        assert !File.exists?(File.join(application_path, "bin", "mock3"))
      end
    end
  end

  def test_fails_when_specified_target_is_not_found
    metadata = {
      targets: { mock: { main: "mock.cr" } }
    }

    with_shard(metadata) do
      Dir.cd(application_path) do
        File.open "mock.cr", "w"
        ex = assert_raises(FailedCommand) { run "shards --no-color build mock_fake" }
        assert_match "E: Error: target 'mock_fake' is not found\n", ex.stdout
        assert_empty ex.stderr
      end
    end
  end
end
