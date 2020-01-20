require "./ext/yaml"

module Shards
  class Dependency < Hash(String, String)
    property name : String

    def self.new(pull : YAML::PullParser) : self
      Dependency.new(pull.read_scalar).tap do |dependency|
        pull.each_in_mapping do
          key = pull.read_scalar
          value = pull.read_scalar

          # HACK: user/repo is case insensitive in github repositories, we thus
          # linearize the dependency definition to always be lowercase to avoid
          # issues later (e.g. cloning a repository multiple times in the cache)
          value = value.downcase if key == "github"

          dependency[key] = value
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

    def inspect(io)
      io << "#<" << self.class.name << " {" << name << " => "
      super
      io << "}>"
    end
  end
end
