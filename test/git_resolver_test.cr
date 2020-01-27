require "./test_helper"

module Shards
  class GitResolverTest < Minitest::Test
    def setup
      create_git_repository "empty"
      create_git_commit "empty", "initial release"

      create_git_repository "library", "0.0.1", "0.1.0", "0.1.1", "0.1.2"
      create_git_release "library", "0.2.0", shard: "name: library\nversion: 0.2.0\nauthors:\n  - julien <julien@portalier.com>"

      # Create a version tag not prefixed by 'v' which should be ignored
      create_git_tag "library", "99.9.9"
    end

    def test_available_versions
      assert_equal ["HEAD"], resolver("empty").available_versions
      assert_equal ["0.0.1", "0.1.0", "0.1.1", "0.1.2", "0.2.0"], resolver("library").available_versions
    end

    def test_read_spec
      assert_raises { resolver("empty").read_spec }
      assert_equal "name: library\nversion: 0.2.0\nauthors:\n  - julien <julien@portalier.com>", resolver("library").read_spec
      assert_equal "name: library\nversion: 0.1.1\n", resolver("library").read_spec("0.1.1")
      assert_equal "name: library\nversion: 0.1.1\n", resolver("library").read_spec("0.1.1")
    end

    def test_install
      library = resolver("library")

      library.install("0.1.2")
      assert File.exists?(install_path("library", "src/library.cr"))
      assert File.exists?(install_path("library", "shard.yml"))
      assert_equal "0.1.2", library.installed_spec.not_nil!.version
      # assert File.exists?(install_path("library", "LICENSE"))

      library.install
      assert_equal "0.2.0", library.installed_spec.not_nil!.version
    end

    def test_origin_changed
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
      ]

      same_origins.each do |origin|
        dependency["git"] = origin
        refute library.origin_changed?, origin
      end

      # These alternatives should all trigger origin as changed
      changed_origins = [
        "https://github.com/foo/bar2",
        "https://github.com/foos/bar",
        "https://githubz.com/foo/bar",
        "file:///github.com/foo/bar",
        "",
      ]

      changed_origins.each do |origin|
        dependency["git"] = origin
        assert library.origin_changed?, origin
      end
    end

    def test_install_refs
      skip "TODO: install commit (whatever the version)"
      skip "TODO: install branch (whatever the version)"
      skip "TODO: install tag (whatever the version)"
    end

    private def resolver(name, config = {} of String => String)
      config = config.merge({"git" => git_url(name)})
      dependency = Dependency.new(name, config)
      GitResolver.new(dependency)
    end
  end
end
