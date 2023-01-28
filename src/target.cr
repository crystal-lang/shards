module Shards
  class Target
    property name : String
    property main : String

    def self.new(pull : YAML::PullParser) : self
      start_pos = pull.location
      name = pull.read_scalar
      main = nil

      pull.each_in_mapping do
        if pull.read_scalar == "main"
          main = pull.read_scalar
        end
        # ignore unknown dependency mapping for future extensions
      end

      unless main
        raise YAML::ParseException.new(%(Missing property "main" for target #{name.inspect}), *start_pos)
      end

      Target.new(name, main)
    end

    def initialize(@name, @main)
    end
  end
end
