module Shards
  class Dependency < Hash(String, String)
    property name : String

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
