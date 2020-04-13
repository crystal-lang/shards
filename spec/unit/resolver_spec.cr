require "./spec_helper"

module Shards
  describe Resolver do
    it "find resolver with unordered dependency keys" do
      dependency = Dependency.new("test", git: "file:///tmp/test")
      Shards.find_resolver(dependency).class.should eq(GitResolver)
    end
  end
end
