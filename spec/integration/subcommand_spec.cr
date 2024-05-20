require "./spec_helper"

describe "subcommand" do
  it "forwards all arguments to subcommand" do
    create_shard("dummy", "0.1.0")
    create_executable "dummy", "bin/shards-dummy", %(print "args: "; print ARGV)

    with_path(git_path("dummy/bin")) do
      output = run("shards dummy --no-color --verbose --unknown other argument")
      output.should contain(%(args: ["--no-color", "--verbose", "--unknown", "other", "argument"]))
    end
  end

  it "correctly forwards '--help' option to subcommand" do
    create_shard("dummy", "0.1.0")
    create_executable "dummy", "bin/shards-dummy", %(print "args: "; print ARGV)

    with_path(git_path("dummy/bin")) do
      output = run("shards dummy --help")
      output.should contain(%(args: ["--help"]))
    end
  end
end

private def with_path(path)
  old_path = ENV["PATH"]
  ENV["PATH"] = "#{File.expand_path(path)}#{Process::PATH_DELIMITER}#{ENV["PATH"]}"
  yield
ensure
  ENV["PATH"] = old_path
end
