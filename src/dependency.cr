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

    protected def initialize(@name)
      super()
    end

    protected def initialize(@name, config)
      super()
      config.each { |k, v| self[k.to_s] = v.to_s }
    end

    def version
      version { "*" }
    end

    def version?
      version { nil }
    end

    private def version
      if version = self["version"]?
        version
      elsif self["tag"]? =~ VERSION_TAG
        $1
      else
        yield
      end
    end

    def refs
      self["branch"]? || self["tag"]? || self["commit"]?
    end

    def path
      self["path"]?
    end

    def to_human_requirement
      if version = version?
        version
      elsif branch = self["branch"]?
        "branch #{branch}"
      elsif tag = self["tag"]?
        "tag #{tag}"
      elsif commit = self["commit"]?
        "commit #{commit}"
      else
        "*"
      end
    end

    def to_s(io)
      io << name << " " << version
    end

    def inspect(io)
      io << "#<" << self.class.name << " {" << name << " => "
      super
      io << "}>"
    end
  end
end
