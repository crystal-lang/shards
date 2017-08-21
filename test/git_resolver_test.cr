require "./test_helper"

module Shards
  class GitResolverTest < Minitest::Test
    def setup
      create_git_repository "empty"
      create_git_commit "empty", "initial release"

      create_git_repository "legacy"
      create_git_release "legacy", "1.0.0", shard: false

      create_git_repository "library", "0.0.1", "0.1.0", "0.1.1", "0.1.2"
      create_git_release "library", "0.2.0", shard: "name: library\nversion: 0.2.0\nauthors:\n  - julien <julien@portalier.com>"
    end

    def test_available_versions
      assert_equal ["HEAD"], resolver("empty").available_versions
      assert_equal ["1.0.0"], resolver("legacy").available_versions
      assert_equal ["0.0.1", "0.1.0", "0.1.1", "0.1.2", "0.2.0"], resolver("library").available_versions

      refs = git_commits("library")
      assert_equal ["0.0.1"], resolver("library", { "commit" => refs.last }).available_versions
      assert_equal ["0.2.0"], resolver("library", { "commit" => refs.first }).available_versions
      assert_equal ["0.1.2"], resolver("library", { "tag" => "v0.1.2" }).available_versions
      assert_equal ["0.2.0"], resolver("library", { "branch" => "master" }).available_versions
    end

    def test_read_spec
      assert_equal "name: empty\nversion: #{DEFAULT_VERSION}\n", resolver("empty").read_spec
      assert_equal "name: legacy\nversion: 1.0.0\n", resolver("legacy").read_spec
      assert_equal "name: library\nversion: 0.2.0\nauthors:\n  - julien <julien@portalier.com>", resolver("library").read_spec
      assert_equal "name: library\nversion: 0.1.1\n", resolver("library").read_spec("0.1.1")
      assert_equal "name: library\nversion: 0.1.1\n", resolver("library").read_spec("0.1.1")
    end

    def test_install
      library, legacy = resolver("library"), resolver("legacy")

      library.install("0.1.2")
      assert File.exists?(install_path("library", "src/library.cr"))
      assert File.exists?(install_path("library", "shard.yml"))
      assert_equal "0.1.2", library.installed_spec.not_nil!.version
      #assert File.exists?(install_path("library", "LICENSE"))

      library.install
      assert_equal "0.2.0", library.installed_spec.not_nil!.version

      legacy.install
      assert File.exists?(install_path("legacy", "src/legacy.cr"))
      assert File.exists?(install_path("legacy", "shard.yml"))

      legacy.install("1.0.0")
      assert File.exists?(install_path("legacy", "src/legacy.cr"))
      assert File.exists?(install_path("legacy", "shard.yml"))
      assert_equal "1.0.0", legacy.installed_spec.not_nil!.version
    end

    def test_install_generates_missing_shard_yml
      create_file "empty", "Projectfile",
        "deps do\n  github \"user/repo\"\n  github \"other/book\", branch: \"unstable\"\nend"
      create_git_commit "empty"

      empty = resolver("empty")

      empty.install # HEAD
      assert File.exists?(install_path("empty", "src/empty.cr"))
      assert File.exists?(install_path("empty", "shard.yml"))

      spec = empty.installed_spec.not_nil!
      assert_equal DEFAULT_VERSION, spec.version
      assert_equal 2, spec.dependencies.size
      repo, book = spec.dependencies

      assert_equal "repo", repo.name
      assert_equal "user/repo", repo["github"]
      refute repo["branch"]?

      assert_equal "book", book.name
      assert_equal "other/book", book["github"]
      assert_equal "unstable", book["branch"]
    end

    def test_install_refs
      skip "TODO: install commit (whatever the version)"
      skip "TODO: install branch (whatever the version)"
      skip "TODO: install tag (whatever the version)"
    end

    def test_parses_dependencies_from_legacy_projectfile
      create_file "legacy", "Projectfile",
        "deps do\n  github \"user/project\"\n  github \"other/library\", branch: \"1-0-stable\"\nend"
      create_git_release "legacy", "1.0.1", shard: false

      spec = resolver("legacy").spec("1.0.1")

      assert_equal "1.0.1", spec.version
      assert_equal 2, spec.dependencies.size

      project, library = spec.dependencies
      assert_equal "project", project.name
      assert_equal "user/project", project["github"]
      refute project["branch"]?

      assert_equal "library", library.name
      assert_equal "other/library", library["github"]
      assert_equal "1-0-stable", library["branch"]
    end

    private def resolver(name, config = {} of String => String)
      config = config.merge({ "git" => git_url(name) })
      dependency = Dependency.new(name, config)
      GitResolver.new(dependency)
    end
  end
end
