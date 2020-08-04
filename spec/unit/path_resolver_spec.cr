require "./spec_helper"

private def resolver(name)
  Shards::PathResolver.new(name, git_path(name))
end

module Shards
  describe PathResolver do
    before_each do
      create_path_repository "library", "1.2.3"
    end

    it "available versions" do
      resolver("library").available_releases.should eq([version "1.2.3"])
    end

    it "read spec" do
      resolver("library").spec("1.2.3").version.should eq(version "1.2.3")
    end

    it "install" do
      resolver("library").tap do |library|
        library.install_sources(version("1.2.3"), install_path("library"))
        File.exists?(install_path("library", "src/library.cr")).should be_true
        File.exists?(install_path("library", "shard.yml")).should be_true
        Spec.from_file(install_path("library", "shard.yml")).version.should eq(version "1.2.3")
      end
    end

    it "install fails when path doesnt exist" do
      expect_raises(Error) do
        resolver("unknown").install_sources(version("1.0.0"), install_path("unknown"))
      end
    end

    it "renders report version" do
      resolver("library").report_version(version "1.2.3").should eq("1.2.3 at #{git_path("library")}")
    end
  end
end
