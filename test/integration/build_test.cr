require "../integration_helper"

class BuildCommandTest < Minitest::Test
  def setup
    Dir.mkdir(File.join(application_path, "src"))
    File.write(File.join(application_path, "src", "cli.cr"), "puts __FILE__")

    Dir.mkdir(File.join(application_path, "src", "commands"))
    File.write(File.join(application_path, "src", "commands", "check.cr"), "puts __LINE__")

    File.write File.join(application_path, "shard.yml"), <<-YAML
      name: build
      version: 0.1.0
      targets:
        app:
          main: src/cli.cr
        alt:
          main: src/cli.cr
        check:
          main: src/commands/check.cr
    YAML
  end

  def bin_path(name)
    File.join(application_path, "bin", name)
  end

  def test_builds_all_targets
    Dir.cd(application_path) do
      run "shards build --no-color"

      assert File.exists?(bin_path("app"))
      assert File.exists?(bin_path("alt"))
      assert File.exists?(bin_path("check"))

      assert_equal File.join(application_path, "src", "cli.cr"), `#{bin_path("app")}`.chomp
      assert_equal File.join(application_path, "src", "cli.cr"), `#{bin_path("alt")}`.chomp
      assert_equal "1", `#{bin_path("check")}`.chomp
    end
  end

  def test_builds_specified_targets
    Dir.cd(application_path) do
      run "shards build --no-color alt check"
      refute File.exists?(bin_path("app"))
      assert File.exists?(bin_path("alt"))
      assert File.exists?(bin_path("check"))
    end
  end

  def test_fails_to_build_unknown_target
    Dir.cd(application_path) do
      ex = assert_raises(FailedCommand) do
        run "shards build --no-color app unknown check"
      end
      assert_match "target unknown was not found", ex.stdout
      assert File.exists?(bin_path("app"))
      refute File.exists?(bin_path("check"))
    end
  end

  def test_reports_error_when_target_failed_to_compile
    File.write File.join(application_path, "src", "cli.cr"), "a = ..."

    Dir.cd(application_path) do
      ex = assert_raises(FailedCommand) do
        run "shards build --no-color app"
      end
      assert_match "target app failed to compile", ex.stdout
      assert_match "Syntax error", ex.stdout
      refute File.exists?(bin_path("app"))
    end
  end
end
