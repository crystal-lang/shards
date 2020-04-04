require "../../../src/commands/info"
require "../spec_helper"
require "../../support/cli"

private def capture(command, *args)
  String.build do |io|
    command.run(args.to_a, stdout: io)
  end.chomp
end

describe Shards::Commands::Info do
  it "reports name" do
    with_shard({name: "foo", version: "1.2.3"}) do
      info = Shards::Commands::Info.new(application_path)

      capture(info, "--name").should eq "foo"
      capture(info, "--version").should eq "1.2.3"
      capture(info, "").should eq <<-OUT
           name: foo
        version: 1.2.3
        OUT
    end
  end
end
