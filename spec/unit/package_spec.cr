require "./spec_helper"
require "../../src/package"

private def resolver(name)
  Shards::PathResolver.new(name, git_path(name))
end

private def git_resolver(name)
  Shards::GitResolver.new(name, git_path(name))
end

module Shards
  describe Package do
    before_each do
      create_path_repository "library", "1.2.3"
      create_git_repository "repo", "0.1.2", "0.1.3"
    end

    it "installs" do
      package = Package.new("library", resolver("library"), version "1.2.3")
      package.installed?.should be_false
      package.install
      package.installed?.should be_true
    end

    it "reads spec from installed dir" do
      package = Package.new("repo", git_resolver("repo"), version "0.1.2")
      package.install

      File.open(install_path("repo", "shard.yml"), "a") do |f|
        f.puts "license: FOO"
      end

      package.spec.license.should eq("FOO")
    end

    it "fallback to resolver to read spec" do
      package = Package.new("repo", git_resolver("repo"), version "0.1.2")
      package.install
      File.delete install_path("repo", "shard.yml")
      package.spec.version.should eq(version "0.1.2")
    end

    it "reads spec from resolver if not installed" do
      package = Package.new("repo", git_resolver("repo"), version "0.1.3")
      package.install

      package = Package.new("repo", git_resolver("repo"), version "0.1.2")
      package.spec.original_version.should eq(version "0.1.2")
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
