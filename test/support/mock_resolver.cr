require "../../src/helpers/natural_sort"

module Shards
  class MockResolver < Resolver
    include Helpers::NaturalSort

    def self.key
      "mock"
    end

    def read_spec(version = nil)
      specs = @@specs[dependency.name].not_nil!
      unless version
        version = specs.keys.sort { |a, b| natural_sort(a, b) }.first?
      end
      specs[version.to_s]
    end

    def available_versions
      if specs = @@specs[dependency.name]?
        specs.keys
      else
        [] of String
      end
    end

    @@specs = {} of String => Hash(String, String)

    def self.register_spec(name, version = "0.0.0", dependencies = nil, development = nil)
      spec = "name: #{ name.inspect }\n"
      spec += "version: #{ version.inspect }\n"

      if dependencies
        spec += "dependencies:\n#{ to_yaml(dependencies) }\n"
      end

      if development
        spec += "development_dependencies:\n#{ to_yaml(development) }\n"
      end

      specs = @@specs[name] ||= {} of String => String
      specs[version.to_s] = spec

      nil
    end

    def self.clear_specs
      @@specs.clear
    end

    def installed_commit_hash
      raise ArgumentError.new("abstract")
    end

    private def self.to_yaml(dependencies)
      yaml = dependencies.map do |dep|
        ary = dep.split(":", 2)

        if ary.size == 2
          "  #{ ary[0] }:\n    mock: \"test\"\n    version: #{ ary[1].inspect }"
        else
          "  #{ ary[0] }:\n    mock: \"test\""
        end
      end

      yaml.join("\n")
    end
  end

  register_resolver MockResolver
end
