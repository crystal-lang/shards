require "./spec_helper"

private def bin_path(name)
  File.join(application_path, "bin", Shards::Helpers.exe(name))
end

describe "build" do
  before_each do
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

  it "builds all targets" do
    Dir.cd(application_path) do
      run "shards build --no-color"

      File.exists?(bin_path("app")).should be_true
      File.exists?(bin_path("alt")).should be_true
      File.exists?(bin_path("check")).should be_true

      `#{Process.quote(bin_path("app"))}`.chomp.should eq(File.join(application_path, "src", "cli.cr"))
      `#{Process.quote(bin_path("alt"))}`.chomp.should eq(File.join(application_path, "src", "cli.cr"))
      `#{Process.quote(bin_path("check"))}`.chomp.should eq("1")
    end
  end

  it "builds specified targets" do
    Dir.cd(application_path) do
      run "shards build --no-color alt check"
      File.exists?(bin_path("app")).should be_false
      File.exists?(bin_path("alt")).should be_true
      File.exists?(bin_path("check")).should be_true
    end
  end

  it "fails to build unknown target" do
    Dir.cd(application_path) do
      ex = expect_raises(FailedCommand) do
        run "shards build --no-color app unknown check"
      end
      ex.stdout.should contain("target unknown was not found")
      File.exists?(bin_path("app")).should be_true
      File.exists?(bin_path("check")).should be_false
    end
  end

  it "reports error when target failed to compile" do
    File.write File.join(application_path, "src", "cli.cr"), "a = ......"

    Dir.cd(application_path) do
      ex = expect_raises(FailedCommand) do
        run "shards build --no-color app"
      end
      ex.stdout.should contain("target app failed to compile")
      ex.stdout.should match(/unexpected token: "?.../)
      File.exists?(bin_path("app")).should be_false
    end
  end

  it "reports warning without failing" do
    File.write File.join(application_path, "src", "cli.cr"), <<-CODE
      @[Deprecated]
      def a
      end
      a
      CODE

    Dir.cd(application_path) do
      err = run "shards build --no-color app"
      err.should match(/eprecated/)
      File.exists?(bin_path("app")).should be_true
    end
  end

  it "errors when no targets defined" do
    File.write File.join(application_path, "shard.yml"), <<-YAML
      name: build
      version: 0.1.0
    YAML

    Dir.cd(application_path) do
      ex = expect_raises(FailedCommand) do
        run "shards build --no-color"
      end
      ex.stdout.should contain("Targets not defined in shard.yml")
      File.exists?(bin_path("")).should be_false
    end
  end
end
