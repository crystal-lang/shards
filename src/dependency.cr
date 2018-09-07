require "./ext/yaml"

module Shards
  class Dependency
    property name : String

    @store = {} of String => String
    forward_missing_to @store

    def self.new(pull : YAML::PullParser) : self
      Dependency.new(pull.read_scalar).tap do |dependency|
        pull.each_in_mapping do
          dependency[pull.read_scalar] = pull.read_scalar
        end
      end
    end

    def initialize(@name)
    end

    # DEPRECATED: with no replacement
    def initialize(@name, config)
      config.each { |k, v| @store[k.to_s] = v.to_s }
    end

    def version
      @store.fetch("version", "*")
    end

    def refs
      @store["branch"]? || @store["tag"]? || @store["commit"]?
    end

    def inspect(io)
      io << "#<" << self.class.name << " {" << name << " => "
      @store.inspect(io)
      io << "}>"
    end
  end
end
