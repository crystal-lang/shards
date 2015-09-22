require "./test_helper"

module Shards
  class PathResolverTest < Minitest::Test
    def setup
      create_path_repository "legacy"
      create_path_repository "library", "1.2.3"
    end

    def test_available_versions
      assert_equal ["0"], resolver("legacy").available_versions
      assert_equal ["1.2.3"], resolver("library").available_versions
    end

    def test_read_spec
      assert_equal "name: legacy\nversion: 0\n", resolver("legacy").read_spec
      assert_equal "name: library\nversion: 1.2.3\n", resolver("library").read_spec
    end

    def test_install
      resolver("library").tap do |library|
        library.install
        assert File.exists?(install_path("library", "library.cr"))
        refute File.exists?(install_path("library", "shard.yml"))
        assert_equal "1.2.3", library.installed_spec.not_nil!.version
      end

      resolver("legacy").tap do |legacy|
        legacy.install
        assert File.exists?(install_path("legacy", "legacy.cr"))
        refute File.exists?(install_path("legacy", "shard.yml"))
        assert_equal "0", legacy.installed_spec.not_nil!.version
      end
    end

    private def resolver(name, config = {} of String => String)
      config["path"] = git_path(name)
      dependency = Dependency.new(name, config)
      PathResolver.new(dependency)
    end
  end
end
