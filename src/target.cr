module Shards
  class Target
    property name : String
    property main : String

    getter attributes : Hash(String, YAML::Any)

    def self.new(pull : YAML::PullParser) : self
      name = pull.read_scalar
      main = nil
      extra_attributes = {} of String => YAML::Any

      pull.each_in_mapping do
        case key = pull.read_scalar
        when "main"
          main = pull.read_scalar
        else
          extra_attributes[key] = YAML::Any.new(pull.read_scalar)
        end
      end

      unless main
        raise "Missing attribute 'main' for target #{name.inspect}"
      end

      Target.new(name, main, extra_attributes)
    end

    def initialize(@name : String, @main : String, @attributes = {} of String => YAML::Any)
    end

    def source_path : String
      main
    end

    def output_path : String
      File.join(Shards.bin_path, name)
    end
  end
end
