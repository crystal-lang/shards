require "./ext/yaml"

module Shards
  class Dependency < Hash(String, String)
    property name : String

    def self.new(pull : YAML::PullParser) : self
      Dependency.new(pull.read_scalar).tap do |dependency|
        pull.each_in_mapping do
          dependency[pull.read_scalar] = pull.read_scalar
        end
      end
    end

    def initialize(@name)
      super()
    end

    # DEPRECATED: with no replacement
    def initialize(@name, config)
      super()
      config.each { |k, v| self[k.to_s] = v.to_s }
    end

    def version
      fetch("version", "*")
    end

    def refs
      self["branch"]? || self["tag"]? || self["commit"]?
    end

    def inspect(io)
      io << "#<" << self.class.name << " {" << name << " => "
      super
      io << "}>"
    end
  end
end
