require "./test_helper"

module Shards
  def self.clear_cache
    @@resolvers.clear
  end

  class ManagerTest < Minitest::Test
    def setup
      MockResolver.register_spec("base", version: "0.1.0")
      MockResolver.register_spec("base", version: "0.2.0")

      MockResolver.register_spec("minitest", version: "0.1.1")

      MockResolver.register_spec("legacy", version: "1.0.0", dependencies: %w(base:~>0.1.0))
      MockResolver.register_spec("collection", version: "1.0.0", dependencies: %w(base:>0.2.0))

      MockResolver.register_spec("library", version: "0.0.1")
      MockResolver.register_spec("library", version: "0.1.0")
      MockResolver.register_spec("library", version: "0.1.1")
      MockResolver.register_spec("library", version: "0.1.2")
      MockResolver.register_spec("library", version: "0.2.0", dependencies: %w(legacy minitest))

      MockResolver.register_spec("failing", version: "0.1.0", dependencies: %w(legacy collection))

      MockResolver.register_spec("webmock", version: "0.1.0")
      MockResolver.register_spec("framework", dependencies: %w(base), development: %w(legacy))
      MockResolver.register_spec("ide", dependencies: %w(framework), development: %w(minitest))
    end

    def teardown
      Shards.clear_cache
      MockResolver.clear_specs
    end

    def test_resolve
      manager = manager_for({
        "name" => "test",
        "dependencies" => {
          "base" => { "mock" => "test" }
        }
      })
      manager.resolve
      assert_equal 1, manager.packages.size
      assert_equal "base", manager.packages.first.name
    end

    def test_resolves_recursively
      manager = manager_for({
        "name" => "test",
        "dependencies" => {
          "library" => { "mock" => "test", "version" => "0.2.0" }
        }
      })
      manager.resolve
      assert_equal 4, manager.packages.size
      assert_equal %w(base legacy library minitest), manager.packages.map(&.name).sort
    end

    def test_resolves_version_requirements
      assert_resolves "0.1.0", "0.1.0"

      assert_resolves "0.2.0", "> 0.1.2"
      assert_resolves "0.2.0", ">= 0.2.0"
      assert_resolves "0.2.0", ">= 0.1.2"

      assert_resolves "0.0.1", "< 0.1.0"
      assert_resolves "0.1.2", "< 0.2.0"
      assert_resolves "0.1.0", "<= 0.1.0"
      assert_resolves "0.2.0", "<= 0.2.0"

      assert_resolves "0.1.2", "~> 0.1.0"
      assert_resolves "0.2.0", "~> 0.1"
    end

    def test_fails_to_resolve_with_incompatible_version_requirements
      manager = manager_for({
        "name" => "test",
        "dependencies" => {
          "failing" => { "mock" => "test" }
        }
      })
      ex = assert_raises(Shards::Conflict) { manager.resolve }
      assert_equal "Error resolving base (~>0.1.0, >0.2.0)", ex.message
    end

    def test_resolves_development_dependencies
      manager = manager_for({
        "name" => "test",
        "dependencies" => {
          "ide" => { "mock" => "test" }
        },
        "development_dependencies" => {
          "webmock" => { "mock" => "test" },
        }
      })
      manager.resolve

      assert_equal 4, manager.packages.size
      assert_equal %w(base framework ide webmock), manager.packages.map(&.name).sort
    end

    private def manager_for(config)
      yaml = String.build do |yml|
        yml << "name: " << config["name"] << "\n"
        yml << "version: " << config.fetch("version", "0.0.0") << "\n"

        if dependencies = config["dependencies"]?
          yml << "dependencies:\n"

          dependencies.as(Hash).each do |name, hsh|
            yml << "  " << name << ": " << "\n"
            hsh.as(Hash).each { |k, v| yml << "    " << k << ": " << v.inspect << "\n" }
          end
        end

        if dependencies = config["development_dependencies"]?
          yml << "development_dependencies:\n"

          dependencies.as(Hash).each do |name, hsh|
            yml << "  " << name << ": " << "\n"
            hsh.as(Hash).each { |k, v| yml << "    " << k << ": " << v.inspect << "\n" }
          end
        end
      end

      spec = Spec.from_yaml(yaml)
      Manager.new(spec)
    end


    private def assert_resolves(version, requirement, dependency = "library")
      manager = manager_for({
        "name" => "test",
        "dependencies" => {
          dependency => { "mock" => "test", "version" => requirement }
        }
      })
      manager.resolve

      if pkg = manager.packages.find { |pkg| pkg.name == dependency }
        assert_equal version, pkg.version, "expected #{ dependency} #{ requirement } to resolve to #{ version } but was #{ pkg.version }"
      else
        assert pkg, "expected #{dependency } #{ requirement } to resolve to #{ version } but got nothing"
      end
    end
  end
end
