require "./spec_helper"

private def resolver(name)
  Shards::GitResolver.new(name, git_url(name))
end

module Shards
  # Allow overriding `source` for the specs
  class GitResolver
    def source=(@source)
    end
  end

  describe GitResolver do
    before_each do
      create_git_repository "empty"
      create_git_commit "empty", "initial release"

      create_git_repository "unreleased"
      create_git_version_commit "unreleased", "0.1.0"
      checkout_new_git_branch "unreleased", "branch"
      create_git_commit "unreleased", "testing"
      checkout_git_branch "unreleased", "master"

      create_git_repository "library", "0.0.1", "0.1.0", "0.1.1", "0.1.2"
      create_git_release "library", "0.2.0", shard: "name: library\nversion: 0.2.0\nauthors:\n  - julien <julien@portalier.com>"

      # Create a version tag not prefixed by 'v' which should be ignored
      create_git_tag "library", "99.9.9"
    end

    it "available releases" do
      resolver("empty").available_releases.should be_empty
      resolver("library").available_releases.should eq(versions ["0.0.1", "0.1.0", "0.1.1", "0.1.2", "0.2.0"])
    end

    it "latest version for ref" do
      resolver("empty").latest_version_for_ref(branch "master").should be_nil
      resolver("empty").latest_version_for_ref(nil).should be_nil
      resolver("unreleased").latest_version_for_ref(branch "master").should eq(version "0.1.0+git.commit.#{git_commits(:unreleased)[0]}")
      resolver("unreleased").latest_version_for_ref(branch "branch").should eq(version "0.1.0+git.commit.#{git_commits(:unreleased, "branch")[0]}")
      resolver("unreleased").latest_version_for_ref(nil).should eq(version "0.1.0+git.commit.#{git_commits(:unreleased)[0]}")
      resolver("library").latest_version_for_ref(branch "master").should eq(version "0.2.0+git.commit.#{git_commits(:library)[0]}")
      resolver("library").latest_version_for_ref(nil).should eq(version "0.2.0+git.commit.#{git_commits(:library)[0]}")
      resolver("library").latest_version_for_ref(branch "foo").should be_nil
    end

    it "versions for" do
      resolver("empty").versions_for(Any).should be_empty
      resolver("library").versions_for(Any).should eq(versions ["0.0.1", "0.1.0", "0.1.1", "0.1.2", "0.2.0"])
      resolver("library").versions_for(VersionReq.new "~> 0.1.0").should eq(versions ["0.1.0", "0.1.1", "0.1.2"])
      resolver("library").versions_for(branch "master").should eq(versions ["0.2.0+git.commit.#{git_commits(:library)[0]}"])
      resolver("unreleased").versions_for(branch "master").should eq(versions ["0.1.0+git.commit.#{git_commits(:unreleased)[0]}"])
      resolver("unreleased").versions_for(Any).should eq(versions ["0.1.0+git.commit.#{git_commits(:unreleased)[0]}"])
    end

    it "read spec for release" do
      spec = resolver("library").spec(version "0.1.1")
      spec.original_version.should eq(version "0.1.1")
      spec.version.should eq(version "0.1.1")
    end

    it "read spec for commit" do
      version = version("0.2.0+git.commit.#{git_commits(:library)[0]}")
      spec = resolver("library").spec(version)
      spec.original_version.should eq(version "0.2.0")
      spec.version.should eq(version)
    end

    it "install" do
      library = resolver("library")

      library.install(version "0.1.2")
      File.exists?(install_path("library", "src/library.cr")).should be_true
      File.exists?(install_path("library", "shard.yml")).should be_true
      library.installed_spec.not_nil!.version.should eq(version "0.1.2")

      library.install(version "0.2.0")
      library.installed_spec.not_nil!.version.should eq(version "0.2.0")
    end

    it "install commit" do
      library = resolver("library")
      version = version "0.2.0+git.commit.#{git_commits(:library)[0]}"
      library.install(version)
      library.installed_spec.not_nil!.version.should eq(version)
    end

    it "origin changed" do
      library = GitResolver.new("library", git_url("library"))
      library.install(version "0.1.2")

      # Change the origin in the cache repo to https://github.com/foo/bar
      Dir.cd(library.local_path) do
        run "git remote set-url origin https://github.com/foo/bar"
      end
      #
      # All of these alternatives should not trigger origin as changed
      same_origins = [
        "https://github.com/foo/bar",
        "https://github.com:1234/foo/bar",
        "http://github.com/foo/bar",
        "ssh://github.com/foo/bar",
        "git://github.com/foo/bar",
        "rsync://github.com/foo/bar",
        "git@github.com:foo/bar",
        "bob@github.com:foo/bar",
        "github.com:foo/bar",
      ]

      same_origins.each do |origin|
        library.source = origin
        library.origin_changed?.should be_false
      end

      # These alternatives should all trigger origin as changed
      changed_origins = [
        "https://github.com/foo/bar2",
        "https://github.com/foos/bar",
        "https://githubz.com/foo/bar",
        "file:///github.com/foo/bar",
        "git@github.com:foo/bar2",
        "git@github2.com:foo/bar",
        "",
      ]

      changed_origins.each do |origin|
        library.source = origin
        library.origin_changed?.should be_true
      end
    end

    it "renders report version" do
      resolver("library").report_version(version "1.2.3").should eq("1.2.3")
      resolver("library").report_version(version "1.2.3+git.commit.654875c9dbfa8d72fba70d65fd548d51ffb85aff").should eq("1.2.3 at 654875c")
    end
  end
end
