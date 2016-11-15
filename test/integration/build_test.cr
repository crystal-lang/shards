require "../integration_helper"

class BuildCommandTest < Minitest::Test

  def test_succeeds_for_default
    metadata = {
      targets: { default: { main: "mock.cr" } }
    }
    
    with_shard(metadata) do
      Dir.cd(application_path) do
        File.open "mock.cr", "w"
        run "shards build"
        assert File.exists?(File.join(application_path, "mock"))
      end
    end
  end

  def test_succeeds_for_default_with_options
    metadata = {
      targets: { default: { main: "mock.cr", options: ["--release"] } }
    }
    
    with_shard(metadata) do
      Dir.cd(application_path) do
        File.open "mock.cr", "w"
        run "shards build"
        assert File.exists?(File.join(application_path, "mock"))
      end
    end
  end

  def test_succeeds_for_specified_target
    metadata = {
      targets: { mock: { main: "mock.cr" } }
    }

    with_shard(metadata) do
      Dir.cd(application_path) do
        File.open "mock.cr", "w"
        run "shards build mock"
        assert File.exists?(File.join(application_path, "mock"))
      end
    end
  end

  def test_succeeds_for_all_targets
    metadata = { targets: {
                   mock1: { main: "mock1.cr" },
                   mock2: { main: "mock2.cr" }
                 } }

    with_shard(metadata) do
      Dir.cd(application_path) do
        File.open "mock1.cr", "w"
        File.open "mock2.cr", "w"
        run "shards build all"
        assert File.exists?(File.join(application_path, "mock1"))
        assert File.exists?(File.join(application_path, "mock2"))
      end
    end
  end

  def test_fails_when_target_is_missing
    metadata = { targets: { mock: { main: "mock.cr" } } }

    with_shard(metadata) do
      Dir.cd(application_path) do
        File.open "mock.cr", "w"
        ex = assert_raises(FailedCommand) { run "shards build mock_fake" }
        assert_match "\e[31mTarget\e[0m 'mock_fake' is not found\n", ex.stdout
      end
    end
  end
end
