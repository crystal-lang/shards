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

  describe GitResolver, tags: %w[git] do
    before_each do
      create_git_repository "empty"
      create_git_commit "empty", "initial release"

      create_git_repository "unreleased"
      create_git_version_commit "unreleased", "0.1.0"
      checkout_new_git_branch "unreleased", "branch"
      create_git_commit "unreleased", "testing"
      checkout_git_branch "unreleased", "master"

      create_git_repository "library", "0.0.1", "0.1.0", "0.1.1", "0.1.2", "0.2.0"

      # Create a version tag not prefixed by 'v' which should be ignored
      create_git_tag "library", "99.9.9"
    end

    it "normalizes github bitbucket gitlab sources" do
      # deal with case insensitive paths
      GitResolver.normalize_key_source("github", "repo/path").should eq({"git", "https://github.com/repo/path.git"})
      GitResolver.normalize_key_source("github", "rEpo/pAth").should eq({"git", "https://github.com/repo/path.git"})
      GitResolver.normalize_key_source("github", "REPO/PATH").should eq({"git", "https://github.com/repo/path.git"})
      GitResolver.normalize_key_source("bitbucket", "repo/path").should eq({"git", "https://bitbucket.com/repo/path.git"})
      GitResolver.normalize_key_source("bitbucket", "rEpo/pAth").should eq({"git", "https://bitbucket.com/repo/path.git"})
      GitResolver.normalize_key_source("bitbucket", "REPO/PATH").should eq({"git", "https://bitbucket.com/repo/path.git"})
      GitResolver.normalize_key_source("gitlab", "repo/path").should eq({"git", "https://gitlab.com/repo/path.git"})
      GitResolver.normalize_key_source("gitlab", "rEpo/pAth").should eq({"git", "https://gitlab.com/repo/path.git"})
      GitResolver.normalize_key_source("gitlab", "REPO/PATH").should eq({"git", "https://gitlab.com/repo/path.git"})
      GitResolver.normalize_key_source("codeberg", "REPO/PATH").should eq({"git", "https://codeberg.org/repo/path.git"})

      # normalise full git paths
      GitResolver.normalize_key_source("git", "HTTPS://User:Pass@Github.com/Repo/Path.git?Shallow=true")[1].should eq "https://User:Pass@github.com/repo/path.git?Shallow=true"
      GitResolver.normalize_key_source("git", "HTTPS://User:Pass@Bitbucket.com/Repo/Path.Git?Shallow=true")[1].should eq "https://User:Pass@bitbucket.com/repo/path.git?Shallow=true"
      GitResolver.normalize_key_source("git", "HTTPS://User:Pass@Gitlab.com/Repo/Path?Shallow=true")[1].should eq "https://User:Pass@gitlab.com/repo/path.git?Shallow=true"
      GitResolver.normalize_key_source("git", "HTTPS://User:Pass@www.Github.com/Repo/Path?Shallow=true")[1].should eq "https://User:Pass@github.com/repo/path.git?Shallow=true"
      GitResolver.normalize_key_source("git", "HTTPS://User:Pass@codeBerg.org/Repo/Path.Git?Shallow=true")[1].should eq "https://User:Pass@codeberg.org/repo/path.git?Shallow=true"

      # don't normalise other domains
      GitResolver.normalize_key_source("git", "HTTPs://mygitserver.com/Repo.git").should eq({"git", "HTTPs://mygitserver.com/Repo.git"})

      # don't change protocol from ssh
      GitResolver.normalize_key_source("git", "ssh://git@github.com/Repo/Path?Shallow=true").should eq({"git", "ssh://git@github.com/Repo/Path?Shallow=true"})
    end

    it "available releases" do
      resolver("empty").available_releases.should be_empty
      resolver("library").available_releases.should eq(versions ["0.0.1", "0.1.0", "0.1.1", "0.1.2", "0.2.0"])
    end

    it "latest version for ref" do
      expect_raises(Shards::Error, "No shard.yml was found for shard \"empty\" at commit #{git_commits(:empty)[0]}") do
        resolver("empty").latest_version_for_ref(branch "master")
      end
      expect_raises(Shards::Error, "No shard.yml was found for shard \"empty\" at commit #{git_commits(:empty)[0]}") do
        resolver("empty").latest_version_for_ref(nil)
      end
      resolver("unreleased").latest_version_for_ref(branch "master").should eq(version "0.1.0+git.commit.#{git_commits(:unreleased)[0]}")
      resolver("unreleased").latest_version_for_ref(branch "branch").should eq(version "0.1.0+git.commit.#{git_commits(:unreleased, "branch")[0]}")
      resolver("unreleased").latest_version_for_ref(nil).should eq(version "0.1.0+git.commit.#{git_commits(:unreleased)[0]}")
      resolver("library").latest_version_for_ref(branch "master").should eq(version "0.2.0+git.commit.#{git_commits(:library)[0]}")
      resolver("library").latest_version_for_ref(nil).should eq(version "0.2.0+git.commit.#{git_commits(:library)[0]}")
      expect_raises(Shards::Error, "Could not find branch foo for shard \"library\" in the repository #{git_url(:library)}") do
        resolver("library").latest_version_for_ref(branch "foo")
      end
    end

    it "versions for" do
      expect_raises(Shards::Error, "No shard.yml was found for shard \"empty\" at commit #{git_commits(:empty)[0]}") do
        resolver("empty").versions_for(Any)
      end
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

      library.install_sources(version("0.1.2"), install_path("library"))
      File.exists?(install_path("library", "src/library.cr")).should be_true
      File.exists?(install_path("library", "shard.yml")).should be_true
      Spec.from_file(install_path("library", "shard.yml")).version.should eq(version "0.1.2")

      library.install_sources(version("0.2.0"), install_path("library"))
      Spec.from_file(install_path("library", "shard.yml")).version.should eq(version "0.2.0")
    end

    it "install commit" do
      library = resolver("library")
      version = version "0.2.0+git.commit.#{git_commits(:library)[0]}"
      library.install_sources(version, install_path("library"))
      Spec.from_file(install_path("library", "shard.yml")).version.should eq(version "0.2.0")
    end

    it "origin changed" do
      library = GitResolver.new("library", git_url("library"))
      library.install_sources(version("0.1.2"), install_path("library"))

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

    it "#matches_ref" do
      resolver = GitResolver.new("", "")
      resolver.matches_ref?(GitCommitRef.new("1234567890abcdef"), Shards::Version.new("0.1.0.+git.commit.1234567")).should be_true
      resolver.matches_ref?(GitCommitRef.new("1234567890abcdef"), Shards::Version.new("0.1.0.+git.commit.1234567890abcdef")).should be_true
      resolver.matches_ref?(GitCommitRef.new("1234567"), Shards::Version.new("0.1.0.+git.commit.1234567890abcdef")).should be_true
    end
  end
end
