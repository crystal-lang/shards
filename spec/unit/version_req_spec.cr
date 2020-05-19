require "./spec_helper"

module Shards
  describe VersionReq do
    it "parses" do
      VersionReq.new("~> 1.0").patterns.should eq(["~> 1.0"])
      VersionReq.new("~> 1.0, < 1.8").patterns.should eq(["~> 1.0", "< 1.8"])
      VersionReq.new("~> 1.0,, < 1.8").patterns.should eq(["~> 1.0", "< 1.8"])
    end

    it "to_s" do
      VersionReq.new("~> 1.0").to_s.should eq("~> 1.0")
      VersionReq.new("~> 1.0,< 1.8").to_s.should eq("~> 1.0, < 1.8")
    end

    it "prerelease?" do
      VersionReq.new("~> 1.0").prerelease?.should be_false
      VersionReq.new("~> 1.0-a").prerelease?.should be_true
      VersionReq.new("~> 1.0, < 1.8").prerelease?.should be_false
      VersionReq.new("~> 1.0, < 1.8-a").prerelease?.should be_true
    end
  end
end
