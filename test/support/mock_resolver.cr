require "../src/helpers/natural_sort"

module Shards
  class MockResolver < Resolver
    include Helpers::NaturalSort

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

    def self.register_spec(name, version = nil, as = nil, dependencies = nil, development = nil)
      spec = "name: #{ name.inspect }\n"
      spec += "version: #{ version.inspect }\n" if version

      if dependencies
        yaml = dependencies.map do |dep|
          ary = dep.split(":", 2)

          if ary.size == 2
            "  #{ ary[0] }:\n    mock: \"\"\n    version: #{ ary[1].inspect }"
          else
            "  #{ ary[0] }:\n    mock: \"\""
          end
        end

        spec += "dependencies:\n#{ yaml.join("\n") }\n"
      end

      specs = @@specs[name] ||= {} of String => String
      specs[(as || version).to_s] = spec

      nil
    end

    def self.clear_specs
      @@specs.clear
    end
  end

  register_resolver :mock, MockResolver
end
