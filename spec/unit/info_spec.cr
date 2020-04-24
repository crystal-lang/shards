require "./spec_helper"

module Shards
  describe Info do
    before_each do
      run "rm -rf #{Shards.install_path}/.shards.info"
    end

    it "create with default install directory" do
      info = Info.new
      info.install_path.should eq(install_path)
      info.installed.should be_empty
    end

    it "reads existing file" do
      File.write File.join(install_path, ".shards.info"), SAMPLE_INFO
      info = Info.new
      info.installed.should eq({
        "foo" => Dependency.new("foo", GitResolver.new("foo", "https://example.com/foo.git"), version "1.2.3"),
      })
    end

    it "save changes" do
      info = Info.new
      dep = Dependency.new("foo", GitResolver.new("foo", "https://example.com/foo.git"), version "1.2.3")
      info.installed["foo"] = dep
      info.save

      info_file = File.read File.join(install_path, ".shards.info")
      info_file.should eq(SAMPLE_INFO)
    end
  end

  SAMPLE_INFO = <<-YAML
  ---
  version: 1.0
  shards:
    foo:
      git: https://example.com/foo.git
      version: 1.2.3

  YAML
end
