require "./spec_helper"
require "../../src/package"

private def resolver(name)
  Shards::PathResolver.new(name, git_path(name))
end

module Shards
  describe Package do
    before_each do
      create_path_repository "library", "1.2.3"
    end

    it "installs" do
      package = Package.new("library", resolver("library"), version "1.2.3")
      package.installed?.should be_false
      package.install
      package.installed?.should be_true
    end

    it "different version is not installed" do
      package = Package.new("library", resolver("library"), version "1.2.3")
      package.install

      package2 = Package.new("library", resolver("library"), version "2.0.0")
      package2.installed?.should be_false
    end

    it "different resolver is not installed" do
      package = Package.new("library", resolver("library"), version "1.2.3")
      package.install

      package2 = Package.new("library", resolver("foo"), version "1.2.3")
      package2.installed?.should be_false
    end

    it "not installed if missing target" do
      package = Package.new("library", resolver("library"), version "1.2.3")
      package.install

      run "rm -rf #{install_path("library")}"
      package.installed?.should be_false
    end

    it "cleanups target before installing" do
      Dir.mkdir_p(install_path)
      File.touch(install_path("library"))
      package = Package.new("library", resolver("library"), version "1.2.3")
      package.install

      File.symlink?(install_path("library")).should be_true
    end
  end
end
