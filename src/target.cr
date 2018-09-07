module Shards
  class Target
    property name : String

    @store = {} of String => String
    forward_missing_to @store

    def self.new(pull : YAML::PullParser) : self
      Target.new(pull.read_scalar).tap do |target|
        pull.each_in_mapping do
          target[pull.read_scalar] = pull.read_scalar
        end
      end
    end

    def initialize(@name)
    end

    def main
      @store["main"]
    end
  end
end
