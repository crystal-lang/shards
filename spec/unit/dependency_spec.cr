require "./spec_helper"

module Shards
  describe Dependency do
    it "version" do
      dependency = Dependency.new("app")
      dependency.version?.should be_nil

      dependency = Dependency.new("app")
      dependency.version = "<= 1.0.0"
      dependency.version?.should eq("<= 1.0.0")
      dependency.version.should eq("<= 1.0.0")

      dependency = Dependency.new("app")
      dependency.version = "<= 2.0.0"
      dependency.version?.should eq("<= 2.0.0")
      dependency.version.should eq("<= 2.0.0")
    end

    it "version with tags" do
      dependency = Dependency.new("app")
      dependency.tag = "fix/something"
      dependency.version.should eq("*")

      dependency = Dependency.new("app")
      dependency.tag = "1.2.3"
      dependency.version.should eq("*")

      # version tag is considered a version:
      dependency = Dependency.new("app")
      dependency.tag = "v1.2.3-pre1"
      dependency.version.should eq("1.2.3-pre1")
    end
  end
end
