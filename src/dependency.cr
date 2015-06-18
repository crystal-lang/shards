module Shards
  class Dependency < Hash(String, String)
    getter :name, :config

    def initialize(@name, config)
      super nil
      config.each { |k, v| self[k.to_s] = v.to_s }
    end

    def version
      self["version"]? || "*"
    end

    def refs
      self["commit"]? || self["tag"]? || self["branch"]?
    end

    def inspect(io)
      io << "#<" << self.class.name << " {\"" << name << "\" => "
      super
      io << "}>"
    end
  end
end
