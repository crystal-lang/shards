require "./spec_helper"

private def resolver(name)
  dependency = Shards::Dependency.new(name, path: git_path(name))
  Shards::PathResolver.new(dependency)
end

module Shards
  describe PathResolver do
    before_each do
      create_path_repository "library", "1.2.3"
    end

    it "available versions" do
      resolver("library").available_versions.should eq(["1.2.3"])
    end

    it "read spec" do
      resolver("library").read_spec.should eq("name: library\nversion: 1.2.3\n")
    end

    it "install" do
      resolver("library").tap do |library|
        library.install
        File.exists?(install_path("library", "src/library.cr")).should be_true
        File.exists?(install_path("library", "shard.yml")).should be_true
        library.installed_spec.not_nil!.version.should eq("1.2.3")
      end
    end

    it "install fails when path doesnt exist" do
      expect_raises(Error) { resolver("unknown").install }
    end

    it "installed reports library is installed" do
      resolver("library").tap do |resolver|
        resolver.installed?.should be_false

        resolver.install
        resolver.installed?.should be_true
      end
    end

    it "installed when target is incorrect link" do
      resolver("library").tap do |resolver|
        resolver.install
        resolver.installed?.should be_true
      end
    end

    it "installed when target is incorrect broken link" do
      resolver("library").tap do |resolver|
        File.symlink("/does-not-exist", resolver.install_path)
        resolver.installed?.should be_false

        resolver.install
        resolver.installed?.should be_true
      end
    end

    it "installed when target is dir" do
      resolver("library").tap do |resolver|
        Dir.mkdir_p(resolver.install_path)
        File.touch(File.join(resolver.install_path, "foo"))
        resolver.installed?.should be_false

        resolver.install
        resolver.installed?.should be_true
      end
    end

    it "installed when target is file" do
      resolver("library").tap do |resolver|
        File.touch(resolver.install_path)
        resolver.installed?.should be_false

        resolver.install
        resolver.installed?.should be_true
      end
    end
  end
end
