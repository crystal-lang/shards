module Shards
  class Target < Hash(String, String)
    property name : String

    def self.new(pull : YAML::PullParser) : self
      Target.new(pull.read_scalar).tap do |target|
        pull.each_in_mapping do
          target[pull.read_scalar] = pull.read_scalar
        end
      end
    end

    def initialize(@name)
      super()
    end

    def main
      self["main"]
    end
  end
end
