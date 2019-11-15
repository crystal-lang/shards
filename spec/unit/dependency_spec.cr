require "./spec_helper"

module Shards
  describe Dependency do
    it "version" do
      dependency = Dependency.new("app")
      dependency.version.should eq("*")

      dependency = Dependency.new("app", version: "*")
      dependency.version.should eq("*")

      dependency = Dependency.new("app", version: "1.0.0")
      dependency.version.should eq("1.0.0")

      dependency = Dependency.new("app", version: "<= 2.0.0")
      dependency.version.should eq("<= 2.0.0")
    end

    it "version with tags" do
      dependency = Dependency.new("app", tag: "fix/something")
      dependency.version.should eq("*")

      dependency = Dependency.new("app", tag: "1.2.3")
      dependency.version.should eq("*")

      # version tag is considered a version:
      dependency = Dependency.new("app", tag: "v1.2.3-pre1")
      dependency.version.should eq("1.2.3-pre1")
    end
  end
end
