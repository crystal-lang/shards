require "./spec_helper"

describe "shards info" do
  it "reports name" do
    Dir.cd(application_path) do
      with_shard({name: "foo"}) do
        output = run "shards info --name"
        output.should eq "foo\n"
      end
    end
  end

  it "reports version" do
    Dir.cd(application_path) do
      with_shard({version: "1.2.3"}) do
        output = run "shards info --version"
        output.should eq "1.2.3\n"
      end
    end
  end

  it "reports info" do
    Dir.cd(application_path) do
      with_shard({name: "foo", version: "1.2.3"}) do
        output = run "shards info"
        output.should eq <<-OUT
             name: foo
          version: 1.2.3

          OUT
      end
    end
  end
end
