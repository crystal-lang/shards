require "./test_helper"

module Shards
  class PathResolverTest < Minitest::Test
    def setup
      create_path_repository "legacy"
      create_path_repository "library", "1.2.3"
    end

    def test_available_versions
      assert_equal [DEFAULT_VERSION], resolver("legacy").available_versions
      assert_equal ["1.2.3"], resolver("library").available_versions
    end

    def test_read_spec
      assert_equal "name: legacy\nversion: #{DEFAULT_VERSION}\n", resolver("legacy").read_spec
      assert_equal "name: library\nversion: 1.2.3\n", resolver("library").read_spec
    end

    def test_parses_dependencies_from_legacy_projectfile
      create_file "legacy", "Projectfile",
        "deps do\n  github \"user/project\"\n  github \"other/library\", branch: \"1-0-stable\"\nend"

      spec = resolver("legacy").spec
      project, library = spec.dependencies

      assert_equal "project", project.name
      assert_equal "user/project", project["github"]
      assert_nil project["branch"]?

      assert_equal "library", library.name
      assert_equal "other/library", library["github"]
      assert_equal "1-0-stable", library["branch"]
    end

    def test_install
      resolver("library").tap do |library|
        library.install
        assert File.exists?(install_path("library", "src/library.cr"))
        assert File.exists?(install_path("library", "shard.yml"))
        assert_equal "1.2.3", library.installed_spec.not_nil!.version
      end

      resolver("legacy").tap do |legacy|
        legacy.install
        assert File.exists?(install_path("legacy", "src/legacy.cr"))
        refute File.exists?(install_path("legacy", "shard.yml"))
        assert_equal DEFAULT_VERSION, legacy.installed_spec.not_nil!.version
      end
    end

    def test_install_fails_when_path_doesnt_exist
      assert_raises(Error) { resolver("unknown").install }
    end

    private def resolver(name, config = {} of String => String)
      config["path"] = git_path(name)
      dependency = Dependency.new(name, config)
      PathResolver.new(dependency)
    end
  end
end
