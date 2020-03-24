require "./spec_helper"

def bin_path(name)
  File.join(application_path, "bin", name)
end

describe "run" do
  before_each do
    Dir.mkdir(File.join(application_path, "src"))
    File.write(File.join(application_path, "src", "cli.cr"), "puts __FILE__")
  end

  after_each do
    File.delete File.join(application_path, "shard.yml")
  end

  it "runs specific target" do
    File.write File.join(application_path, "shard.yml"), <<-YAML
      name: build
      version: 0.1.0
      targets:
        app:
          main: src/cli.cr
        alt:
          main: src/cli.cr
      YAML

    Dir.cd(application_path) do
      run "shards run app --no-color"
      File.exists?(bin_path("app")).should be_true
      `#{bin_path("app")}`.chomp.should eq(File.join(application_path, "src", "cli.cr"))
    end
  end

  it "runs when only one target" do
    File.write File.join(application_path, "shard.yml"), <<-YAML
      name: build
      version: 0.1.0
      targets:
        app:
          main: src/cli.cr
      YAML

    Dir.cd(application_path) do
      run "shards run --no-color"
      File.exists?(bin_path("app")).should be_true
      `#{bin_path("app")}`.chomp.should eq(File.join(application_path, "src", "cli.cr"))
    end
  end

  it "fails when multiple targets, no arg" do
    File.write File.join(application_path, "shard.yml"), <<-YAML
      name: build
      version: 0.1.0
      targets:
        app:
          main: src/cli.cr
        alt:
          main: src/cli.cr
      YAML

    Dir.cd(application_path) do
      ex = expect_raises(FailedCommand) do
        run "shards run --no-color"
      end
      ex.stdout.should contain("Error please specify the target with 'shards run target'")
    end
  end

  it "fails when no targets defined" do
    File.write File.join(application_path, "shard.yml"), <<-YAML
      name: build
      version: 0.1.0
      YAML

    Dir.cd(application_path) do
      ex = expect_raises(FailedCommand) do
        run "shards run --no-color"
      end
      ex.stdout.should contain("Error no targets defined")
    end
  end

  it "fails when no targets defined with target" do
    File.write File.join(application_path, "shard.yml"), <<-YAML
      name: build
      version: 0.1.0
      YAML

    Dir.cd(application_path) do
      ex = expect_raises(FailedCommand) do
        run "shards run missing --no-color"
      end
      ex.stdout.should contain("Error target missing was not found in")
    end
  end

  it "fails when passing multiple targets" do
    File.write File.join(application_path, "shard.yml"), <<-YAML
      name: build
      version: 0.1.0
      targets:
        app:
          main: src/cli.cr
        alt:
          main: src/cli.cr
      YAML

    Dir.cd(application_path) do
      ex = expect_raises(FailedCommand) do
        run "shards run app alt --no-color"
      end
      ex.stdout.should contain("Error please specify only one target. If you meant to pass arguments you may use 'shards run target -- args")
    end
  end
end
