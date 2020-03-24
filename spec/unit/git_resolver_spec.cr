require "./spec_helper"

private def resolver(name, config = {} of String => String)
  config = config.merge({"git" => git_url(name)})
  dependency = Shards::Dependency.from_name_config(name, config)
  Shards::GitResolver.new(dependency)
end

module Shards
  describe PathResolver do
    before_each do
      create_git_repository "empty"
      create_git_commit "empty", "initial release"

      create_git_repository "library", "0.0.1", "0.1.0", "0.1.1", "0.1.2"
      create_git_release "library", "0.2.0", shard: "name: library\nversion: 0.2.0\nauthors:\n  - julien <julien@portalier.com>"

      # Create a version tag not prefixed by 'v' which should be ignored
      create_git_tag "library", "99.9.9"
    end

    it "available versions" do
      resolver("empty").available_versions.should eq(["HEAD"])
      resolver("library").available_versions.should eq(["0.0.1", "0.1.0", "0.1.1", "0.1.2", "0.2.0"])
    end

    it "read spec" do
      expect_raises(Error) { resolver("empty").read_spec }
      resolver("library").read_spec.should eq("name: library\nversion: 0.2.0\nauthors:\n  - julien <julien@portalier.com>")
      resolver("library").read_spec("0.1.1").should eq("name: library\nversion: 0.1.1\n")
      resolver("library").read_spec("0.1.1").should eq("name: library\nversion: 0.1.1\n")
    end

    it "install" do
      library = resolver("library")

      library.install("0.1.2")
      File.exists?(install_path("library", "src/library.cr")).should be_true
      File.exists?(install_path("library", "shard.yml")).should be_true
      library.installed_spec.not_nil!.version.should eq("0.1.2")
      # File.exists?(install_path("library", "LICENSE")).should be_true

      library.install
      library.installed_spec.not_nil!.version.should eq("0.2.0")
    end

    it "origin changed" do
      dependency = Dependency.new("library", {"git" => git_url("library")})
      library = GitResolver.new(dependency)
      library.install("0.1.2")

      # Change the origin in the cache repo to https://github.com/foo/bar
      Dir.cd(library.local_path) do
        run "git remote set-url origin https://github.com/foo/bar"
      end

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
        dependency["git"] = origin
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
        dependency["git"] = origin
        library.origin_changed?.should be_true
      end
    end

    pending "install refs" do
      # TODO: install commit (whatever the version)
      # TODO: install branch (whatever the version)
      # TODO: install tag (whatever the version)
    end
  end
end
