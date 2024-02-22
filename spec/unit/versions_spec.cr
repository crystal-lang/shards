require "./spec_helper"

private def resolve(versions : Array(String), req : String) : Array(String)
  Shards::Versions.resolve(versions(versions), version_req req).map &.value
end

private def matches?(version : String, req : String) : Bool
  Shards::Versions.matches?(version(version), version_req(req))
end

module Shards
  describe Versions do
    #   class VersionsTest < Minitest::Test
    it "prerelease?" do
      Versions.prerelease?("1.0").should be_false
      Versions.prerelease?("1.0.0.1").should be_false

      Versions.prerelease?("1.0a").should be_true
      Versions.prerelease?("1.0.alpha").should be_true
      Versions.prerelease?("1.0.0-rc1").should be_true
      Versions.prerelease?("1.0.0-pre.1.2.x.y").should be_true

      Versions.prerelease?("1.0.0-pre+20190129").should be_true
      Versions.prerelease?("1.0+20190129").should be_false
      Versions.prerelease?("1.0+build1").should be_false
    end

    it "compare" do
      # a is older than b:
      Versions.compare("1.0.0", "1.0.1").should eq(1)
      Versions.compare("1.0.0", "2.0.0").should eq(1)
      Versions.compare("1.0", "1.0.0.1").should eq(1)
      Versions.compare("1.0.0", "1.0.0.1").should eq(1)

      # a == b
      Versions.compare("0.1", "0.1").should eq(0)
      Versions.compare("0.1", "0.1.0.0").should eq(0)
      Versions.compare("0.1.0", "0.1").should eq(0)
      Versions.compare("2.0.0", "2.0.0").should eq(0)

      # a is newer than b:
      Versions.compare("1.0.1", "1.0.0").should eq(-1)
      Versions.compare("2.0.0", "1.0.0").should eq(-1)
      Versions.compare("1.0.0.1", "1.0").should eq(-1)
      Versions.compare("1.0.0.1", "1.0.0").should eq(-1)
    end

    it "compare preversions" do
      # a is older than b:
      Versions.compare("1.0.0-beta", "1.0.0").should eq(1)
      Versions.compare("1.0.0.alpha", "1.0.0").should eq(1)
      Versions.compare("1.0.0.alpha", "1.0.0.beta").should eq(1)
      Versions.compare("1.0.beta", "1.0.0").should eq(1)
      Versions.compare("1.0.alpha", "1.0.0-beta").should eq(1)

      Versions.compare("1.0-pre1", "1.0-pre2").should eq(1)
      Versions.compare("1.0-pre2", "1.0-pre10").should eq(1)

      # a == b
      Versions.compare("1.0.0-beta", "1.0.0-beta").should eq(0)
      Versions.compare("1.0.0-alpha", "1.0.0.alpha").should eq(0)
      Versions.compare("1.0.beta", "1.0.0.beta").should eq(0)
      Versions.compare("1.0.beta", "1.0.0.0.0.0.beta").should eq(0)

      # a is newer than b:
      Versions.compare("1.0.0", "1.0.0-beta").should eq(-1)
      Versions.compare("1.0.0", "1.0.0.alpha").should eq(-1)
      Versions.compare("1.0.0.beta", "1.0.0.alpha").should eq(-1)
      Versions.compare("1.0.0", "1.0.beta").should eq(-1)
      Versions.compare("1.0.0-beta", "1.0.alpha").should eq(-1)

      Versions.compare("1.0-pre2", "1.0-pre1").should eq(-1)
      Versions.compare("1.0-pre10", "1.0-pre2").should eq(-1)
    end

    it "compare ignores semver metadata" do
      Versions.compare("1.1+20180110", "1.0+20180110").should eq(-1)
      Versions.compare("1.0+build1", "1.0+build2").should eq(0)
      Versions.compare("1.0+20180110", "1.1+20180110").should eq(1)
    end

    it "sort" do
      100.times do
        versions = %w(
          0.0.1
          0.1.0
          0.1.1
          0.1.2
          0.2.0
          0.2.1
          0.2.10
          0.2.10.1
          0.2.11
          0.10.0
          0.11.0
          0.20.0
          0.20.1
          1.0.0-alpha
          1.0.0.beta
          1.0.0-pre1
          1.0.0-pre2
          1.0.0-rc1
          1.0.0-rc2
          1.0.0-rc10
          1.0.0
        ).shuffle

        Versions.sort(versions).should eq(%w(
          1.0.0
          1.0.0-rc10
          1.0.0-rc2
          1.0.0-rc1
          1.0.0-pre2
          1.0.0-pre1
          1.0.0.beta
          1.0.0-alpha
          0.20.1
          0.20.0
          0.11.0
          0.10.0
          0.2.11
          0.2.10.1
          0.2.10
          0.2.1
          0.2.0
          0.1.2
          0.1.1
          0.1.0
          0.0.1
        ))
      end
    end

    it "resolve any" do
      versions = %w(0.0.1 0.1.0 0.1.1 0.1.2 0.2.0 0.10.0)

      resolve(versions, "*").should eq(versions)
    end

    it "resolve eq" do
      versions = %w(0.0.1 0.1.0 0.1.1 0.1.2 0.2.0 0.10.0)

      resolve(versions, "0.2.0").should eq(["0.2.0"])
      resolve(versions, "0.1.1").should eq(["0.1.1"])
      resolve(versions, "0.10.0").should eq(["0.10.0"])
      resolve(versions, "1.0.0").should be_empty
      resolve(versions, "0.0.1.alpha").should be_empty
    end

    it "resolves neq" do
      versions = %w(0.0.1 0.1.0 0.1.1 0.1.2 0.2.0 0.10.0)

      resolve(versions, "!= 0.1.0").should eq(["0.0.1", "0.1.1", "0.1.2", "0.2.0", "0.10.0"])
      resolve(versions, "!= 0.1.0, != 0.2.0, != 0.10.0").should eq(["0.0.1", "0.1.1", "0.1.2"])
    end

    it "resolve gt" do
      versions = %w(0.0.1 0.1.0 0.1.1 0.1.2 0.2.0 0.10.0)

      resolve(versions, "> 0.1.2").should eq(["0.2.0", "0.10.0"])
      resolve(versions, "> 0.1.1").should eq(["0.1.2", "0.2.0", "0.10.0"])
    end

    it "resolve gte" do
      versions = %w(0.0.1 0.1.0 0.1.1 0.1.2 0.2.0 0.10.0)

      resolve(versions, ">= 0.2.0").should eq(["0.2.0", "0.10.0"])
      resolve(versions, ">= 0.1.2").should eq(["0.1.2", "0.2.0", "0.10.0"])
    end

    it "resolve lt" do
      versions = %w(0.0.1 0.1.0 0.1.1 0.1.2 0.2.0 0.10.0)

      resolve(versions, "< 0.1.0").should eq(["0.0.1"])
      resolve(versions, "< 0.2.0").should eq(["0.0.1", "0.1.0", "0.1.1", "0.1.2"])
    end

    it "resolve lte" do
      versions = %w(0.0.1 0.1.0 0.1.1 0.1.2 0.2.0 0.10.0)

      resolve(versions, "<= 0.1.0").should eq(["0.0.1", "0.1.0"])
      resolve(versions, "<= 0.2.0").should eq(["0.0.1", "0.1.0", "0.1.1", "0.1.2", "0.2.0"])
    end

    it "resolve approximate" do
      versions = %w(0.0.1 0.1.0 0.1.1 0.1.2 0.2.0 0.10.0 1.0.0 1.5.0 2.0.0)

      resolve(versions, "~> 0.1.0").should eq(["0.1.0", "0.1.1", "0.1.2"])
      resolve(versions, "~> 0.1").should eq(["0.1.0", "0.1.1", "0.1.2", "0.2.0", "0.10.0"])
      resolve(versions, "~> 1").should eq(["1.0.0", "1.5.0"])

      resolve(["0.1"], "~> 0.1").should eq(["0.1"])
      resolve(["0.1"], "~> 0.1.0").should eq(["0.1"])
    end

    it "resolve intersection" do
      versions = %w(0.0.1 0.1.0 0.1.1 0.1.2 0.2.0 0.10.0)

      resolve(versions, ">= 0.1.0, < 0.2.0").should eq(["0.1.0", "0.1.1", "0.1.2"])
    end

    it "matches?" do
      matches?("0.1.0", "*").should be_true
      matches?("1.0.0", "*").should be_true

      matches?("1.0.0", "1.0.0").should be_true
      matches?("1.0.0", "1.0").should be_true
      matches?("1.0.0", "1.0.1").should be_false

      matches?("1.0.0", "> 0.1.0, < 1.0.1, != 1.0.0").should be_false
      matches?("0.5.0", "> 0.1, < 1.0, != 0.5").should be_false
      matches?("1.0.1", ">= 1.0.0, != 2.0").should be_true
      matches?("1.8", ">= 1.0.1, != 2.0").should be_true

      matches?("1.0.0", ">= 1.0.0").should be_true
      matches?("1.0.0", ">= 1.0").should be_true
      matches?("1.0.1", ">= 1.0.0").should be_true
      matches?("1.0.0", ">= 1.0.1").should be_false

      matches?("1.0.0", "> 1.0.0").should be_false
      matches?("1.0.0", "> 1.0").should be_false
      matches?("1.0.1", "> 1.0.0").should be_true
      matches?("1.0.0", "> 1.0.1").should be_false

      matches?("1.0.0", "<= 1.0.0").should be_true
      matches?("1.0.0", "<= 1.0").should be_true
      matches?("1.0.1", "<= 1.0.0").should be_false
      matches?("1.0.0", "<= 1.0.1").should be_true

      matches?("1.0.0", "< 1.0.0").should be_false
      matches?("1.0.0", "< 1.0").should be_false
      matches?("1.0.1", "< 1.0.0").should be_false
      matches?("1.0.0", "< 1.0.1").should be_true

      matches?("1.0.0", "~> 1.0.0").should be_true
      matches?("1.0.0", "~> 1.0").should be_true
      matches?("1.0.0", "~> 1").should be_true
      matches?("1.1.0", "~> 1").should be_true
      matches?("1.0.0", "~> 1.1").should be_false
      matches?("2.0.0", "~> 1").should be_false
      matches?("1.0.1", "~> 1.0.0").should be_true
      matches?("1.0.0", "~> 1.0.1").should be_false

      matches?("1.0.0", "> 0.1.0, < 1.0.1").should be_true
      matches?("1.0.1", "> 0.1.0, < 1.0.1").should be_false
    end
  end
end
