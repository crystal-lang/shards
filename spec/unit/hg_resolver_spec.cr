require "./spec_helper"

private def resolver(name)
  Shards::HgResolver.new(name, hg_url(name))
end

module Shards
  # Allow overriding `source` for the specs
  class HgResolver
    def source=(@source)
    end
  end

  describe HgResolver, tags: %w[hg] do
    before_each do
      create_hg_repository "empty"
      create_hg_commit "empty", "initial release"

      create_hg_repository "unreleased"
      create_hg_version_commit "unreleased", "0.1.0"
      checkout_new_hg_branch "unreleased", "branch"
      create_hg_commit "unreleased", "testing"
      checkout_hg_rev "unreleased", "default"

      create_hg_repository "unreleased-bm"
      create_hg_version_commit "unreleased-bm", "0.1.0"
      checkout_new_hg_bookmark "unreleased-bm", "branch"
      create_hg_commit "unreleased-bm", "testing"
      checkout_hg_rev "unreleased-bm", "default"

      create_hg_repository "library", "0.0.1", "0.1.0", "0.1.1", "0.1.2", "0.2.0"

      # Create a version tag not prefixed by 'v' which should be ignored
      create_hg_tag "library", "99.9.9"
    end

    it "normalizes github bitbucket gitlab sources" do
      # don't normalise other domains
      HgResolver.normalize_key_source("hg", "HTTPs://myhgserver.com/Repo").should eq({"hg", "HTTPs://myhgserver.com/Repo"})

      # don't change protocol from ssh
      HgResolver.normalize_key_source("hg", "ssh://hg@myhgserver.com/Repo").should eq({"hg", "ssh://hg@myhgserver.com/Repo"})
    end

    it "available releases" do
      resolver("empty").available_releases.should be_empty
      resolver("library").available_releases.should eq(versions ["0.0.1", "0.1.0", "0.1.1", "0.1.2", "0.2.0"])
    end

    it "latest version for ref" do
      expect_raises(Shards::Error, "No shard.yml was found for shard \"empty\" at commit #{hg_commits(:empty)[0]}") do
        resolver("empty").latest_version_for_ref(hg_branch "default")
      end
      expect_raises(Shards::Error, "No shard.yml was found for shard \"empty\" at commit #{hg_commits(:empty)[0]}") do
        resolver("empty").latest_version_for_ref(nil)
      end
      resolver("unreleased").latest_version_for_ref(hg_branch "default").should eq(version "0.1.0+hg.commit.#{hg_commits(:unreleased)[0]}")
      resolver("unreleased").latest_version_for_ref(hg_branch "branch").should eq(version "0.1.0+hg.commit.#{hg_commits(:unreleased, "branch")[0]}")
      resolver("unreleased").latest_version_for_ref(nil).should eq(version "0.1.0+hg.commit.#{hg_commits(:unreleased)[0]}")
      resolver("unreleased-bm").latest_version_for_ref(hg_branch "default").should eq(version "0.1.0+hg.commit.#{hg_commits("unreleased-bm")[0]}")
      resolver("unreleased-bm").latest_version_for_ref(hg_bookmark "branch").should eq(version "0.1.0+hg.commit.#{hg_commits("unreleased-bm", "branch")[0]}")
      resolver("unreleased-bm").latest_version_for_ref(nil).should eq(version "0.1.0+hg.commit.#{hg_commits("unreleased-bm")[0]}")
      resolver("library").latest_version_for_ref(hg_branch "default").should eq(version "0.2.0+hg.commit.#{hg_commits(:library)[0]}")
      resolver("library").latest_version_for_ref(nil).should eq(version "0.2.0+hg.commit.#{hg_commits(:library)[0]}")
      expect_raises(Shards::Error, "Could not find branch foo for shard \"library\" in the repository #{hg_url(:library)}") do
        resolver("library").latest_version_for_ref(hg_branch "foo")
      end
    end

    it "versions for" do
      expect_raises(Shards::Error, "No shard.yml was found for shard \"empty\" at commit #{hg_commits(:empty)[0]}") do
        resolver("empty").versions_for(Any)
      end
      resolver("library").versions_for(Any).should eq(versions ["0.0.1", "0.1.0", "0.1.1", "0.1.2", "0.2.0"])
      resolver("library").versions_for(VersionReq.new "~> 0.1.0").should eq(versions ["0.1.0", "0.1.1", "0.1.2"])
      resolver("library").versions_for(hg_branch "default").should eq(versions ["0.2.0+hg.commit.#{hg_commits(:library)[0]}"])
      resolver("unreleased").versions_for(hg_branch "default").should eq(versions ["0.1.0+hg.commit.#{hg_commits(:unreleased)[0]}"])
      resolver("unreleased").versions_for(Any).should eq(versions ["0.1.0+hg.commit.#{hg_commits(:unreleased)[0]}"])
      resolver("unreleased-bm").versions_for(hg_branch "default").should eq(versions ["0.1.0+hg.commit.#{hg_commits("unreleased-bm")[0]}"])
      resolver("unreleased-bm").versions_for(Any).should eq(versions ["0.1.0+hg.commit.#{hg_commits("unreleased-bm")[0]}"])
    end

    it "read spec for release" do
      spec = resolver("library").spec(version "0.1.1")
      spec.original_version.should eq(version "0.1.1")
      spec.version.should eq(version "0.1.1")
    end

    it "read spec for commit" do
      version = version("0.2.0+hg.commit.#{hg_commits(:library)[0]}")
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
      version = version "0.2.0+hg.commit.#{hg_commits(:library)[0]}"
      library.install_sources(version, install_path("library"))
      Spec.from_file(install_path("library", "shard.yml")).version.should eq(version "0.2.0")
    end

    it "origin changed" do
      library = HgResolver.new("library", hg_url("library"))
      library.install_sources(version("0.1.2"), install_path("library"))

      # Change the origin in the cache repo to https://foss.heptapod.net/foo/bar
      hgrc_path = File.join(library.local_path, ".hg", "hgrc")
      hgrc = File.read(hgrc_path)
      hgrc = hgrc.gsub(/(default\s*=\s*)([^\r\n]*)/, "\\1https://foss.heptapod.net/foo/bar")
      File.write(hgrc_path, hgrc)
      #
      # All of these alternatives should not trigger origin as changed
      same_origins = [
        "https://foss.heptapod.net/foo/bar",
        "https://foss.heptapod.net:1234/foo/bar",
        "http://foss.heptapod.net/foo/bar",
        "ssh://foss.heptapod.net/foo/bar",
        "hg://foss.heptapod.net/foo/bar",
        "rsync://foss.heptapod.net/foo/bar",
        "hg@foss.heptapod.net:foo/bar",
        "bob@foss.heptapod.net:foo/bar",
        "foss.heptapod.net:foo/bar",
      ]

      same_origins.each do |origin|
        library.source = origin
        library.origin_changed?.should be_false
      end

      # These alternatives should all trigger origin as changed
      changed_origins = [
        "https://foss.heptapod.net/foo/bar2",
        "https://foss.heptapod.net/foos/bar",
        "https://hghubz.com/foo/bar",
        "file:///foss.heptapod.net/foo/bar",
        "hg@foss.heptapod.net:foo/bar2",
        "hg@foss.heptapod2.net.com:foo/bar",
        "",
      ]

      changed_origins.each do |origin|
        library.source = origin
        library.origin_changed?.should be_true
      end
    end

    it "renders report version" do
      resolver("library").report_version(version "1.2.3").should eq("1.2.3")
      resolver("library").report_version(version "1.2.3+hg.commit.654875c9dbfa8d72fba70d65fd548d51ffb85aff").should eq("1.2.3 at 654875c")
    end

    it "#matches_ref" do
      resolver = HgResolver.new("", "")
      resolver.matches_ref?(HgCommitRef.new("1234567890abcdef"), Shards::Version.new("0.1.0.+hg.commit.1234567")).should be_true
      resolver.matches_ref?(HgCommitRef.new("1234567890abcdef"), Shards::Version.new("0.1.0.+hg.commit.1234567890abcdef")).should be_true
      resolver.matches_ref?(HgCommitRef.new("1234567"), Shards::Version.new("0.1.0.+hg.commit.1234567890abcdef")).should be_true
    end
  end
end
