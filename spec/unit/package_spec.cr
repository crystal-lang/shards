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

    it "does not create a lib path for a leaf package" do
      package = Package.new("repo", git_resolver("repo"), version "0.1.2")
      package.install
      File.exists?(install_path("repo", "lib")).should be_false
      File.symlink?(install_path("repo", "lib")).should be_false
    end

    it "does not add dependency links to a path dependency" do
      dependency = Package.new("repo", git_resolver("repo"), version "0.1.2")
      dependency.install
      package = Package.new("library", resolver("library"), version "1.2.3")
      package.dependencies << dependency
      package.install
      File.exists?(File.join(git_path("library"), "lib")).should be_false
    end

    it "preserves a lib directory shipped with the dependency" do
      create_file "repo", "lib/keep.txt", "vendored"
      create_git_release "repo", "0.1.4"
      package = Package.new("repo", git_resolver("repo"), version "0.1.4")
      package.dependencies << Package.new("library", resolver("library"), version "1.2.3")
      package.install
      File.read(install_path("repo", "lib", "keep.txt")).should eq("vendored")
      Dir.children(install_path("repo", "lib")).should eq(["keep.txt"])
    end

    it "does not adopt an existing lib symlink" do
      package = Package.new("repo", git_resolver("repo"), version "0.1.2")
      package.install
      lib_path = install_path("repo", "lib")
      File.symlink("..", lib_path)
      package.dependencies << Package.new("library", resolver("library"), version "1.2.3")
      package.sync_dependency_links
      File.readlink(lib_path).should eq("..")
    end

    it "refreshes a diamond dependency view while preserving user entries" do
      create_path_repository "middle", "1.0.0"
      create_path_repository "leaf", "1.0.0"
      left = Package.new("library", resolver("library"), version "1.2.3")
      right = Package.new("middle", resolver("middle"), version "1.0.0")
      leaf = Package.new("leaf", resolver("leaf"), version "1.0.0")
      [left, right, leaf].each(&.install)
      left.dependencies << leaf
      right.dependencies << leaf
      package = Package.new("repo", git_resolver("repo"), version "0.1.2")
      package.dependencies.concat([left, right])
      package.install

      lib_path = install_path("repo", "lib")
      %w[library middle leaf].each do |name|
        File.same?(File.join(lib_path, name), install_path(name), follow_symlinks: true).should be_true
      end
      File.write(File.join(lib_path, "keep.txt"), "user file")
      File.symlink("keep.txt", File.join(lib_path, "custom"))

      # Remove one target first to exercise cleanup of dangling generated links.
      File.delete(install_path("library"))
      package.dependencies.clear
      package.sync_dependency_links
      %w[library middle leaf].each do |name|
        File.symlink?(File.join(lib_path, name)).should be_false
      end
      File.read(File.join(lib_path, "custom")).should eq("user file")
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

      Shards::Helpers.rm_rf(install_path("library"))
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
