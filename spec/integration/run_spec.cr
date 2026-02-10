require "./spec_helper"

private def bin_path(name)
  File.join(application_path, "bin", Shards::Helpers.exe(name))
end

describe "run" do
  before_each do
    Dir.mkdir(File.join(application_path, "src"))
    File.write(File.join(application_path, "src", "cli.cr"), "puts __FILE__")
  end

  after_each do
    File.delete File.join(application_path, "shard.yml")
  end

  it "fails when no targets defined" do
    File.write File.join(application_path, "shard.yml"), <<-YAML
      name: build
      version: 0.1.0
      YAML

    Dir.cd(application_path) do
      ex = expect_raises(FailedCommand) do
        capture %w[shards run --no-color]
      end
      ex.stdout.should contain("Targets not defined in shard.yml")
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
        capture %w[shards run --no-color app alt]
      end
      ex.stdout.should contain("Error please specify only one target. If you meant to pass arguments you may use 'shards run target -- args'")
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
        capture %w[shards run --no-color]
      end
      ex.stdout.should contain("Error please specify the target with 'shards run target'")
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
      output = capture(%w[shards run --no-color])

      File.exists?(bin_path("app")).should be_true

      output.should contain("Executing: app")
      output.chomp.should contain(File.join(application_path, "src", "cli.cr"))
    end
  end

  it "runs specified target" do
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
      output = capture(%w[shards run --no-color app])

      File.exists?(bin_path("app")).should be_true
      File.exists?(bin_path("alt")).should be_false

      output.should contain("Executing: app")
      output.chomp.should contain(File.join(application_path, "src", "cli.cr"))
    end
  end

  it "passes back execution failure from child process" do
    File.write File.join(application_path, "src", "fail.cr"), <<-CR
      puts "This command fails"
      exit 5
      CR

    File.write File.join(application_path, "shard.yml"), <<-YAML
      name: build
      version: 0.1.0
      targets:
        fail:
          main: src/fail.cr
      YAML

    Dir.cd(application_path) do
      ex = expect_raises(FailedCommand) do
        capture %w[shards run --no-color]
      end
      ex.stdout.should contain("This command fails")
    end
  end

  it "forwards additional ARGV to child process" do
    File.write File.join(application_path, "src", "args.cr"), <<-CR
      print "args: ", ARGV.join(',')
      CR

    File.write File.join(application_path, "shard.yml"), <<-YAML
      name: build
      version: 0.1.0
      targets:
        app:
          main: src/args.cr
      YAML

    Dir.cd(application_path) do
      output = capture(%w[shards run --no-color -- foo bar baz])
      output.should contain("Executing: app foo bar baz")
      output.should contain("args: foo,bar,baz")
    end
  end

  it "works well with stdin" do
    File.write File.join(application_path, "src", "stdin.cr"), <<-CR
      print "input: ", STDIN.gets.inspect
      CR

    File.write File.join(application_path, "shard.yml"), <<-YAML
      name: build
      version: 0.1.0
      targets:
        app:
          main: src/stdin.cr
      YAML

    Dir.cd(application_path) do
      input = IO::Memory.new("hello from stdin")
      output = capture(%w[shards run --no-color], input: input)
      output.should contain("Executing: app")
      output.should contain(%(input: "hello from stdin"))
    end
  end
end
