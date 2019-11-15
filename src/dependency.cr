require "./ext/yaml"

module Shards
  class Dependency
    property name : String
    setter version : String?
    property! resolver : String?
    property! url : String?
    property tag : String?
    property branch : String?
    property commit : String?

    getter unmapped = Hash(String, YAML::Any).new

    def self.new(pull : YAML::PullParser) : self
      dependency = Dependency.new(pull.read_scalar)

      pull.each_in_mapping do
        case key = pull.read_scalar
        when "version"
          dependency.version = pull.read_scalar
        when "url"
          dependency.url = pull.read_scalar
        when "tag"
          dependency.tag = pull.read_scalar
        when "branch"
          dependency.branch = pull.read_scalar
        when "commit"
          dependency.commit = pull.read_scalar
        when "path", "git", "github", "gitlab", "bitbucket"
          if (resolver = dependency.resolver?) && resolver != key
            dependency.unmapped[resolver] = YAML::Any.new(dependency.url)
          end
          dependency.resolver = key
          dependency.url = pull.read_scalar
        else
          dependency.unmapped[key] = YAML::Any.new(pull.read_scalar)
        end
      end

      unless dependency.url?
        raise "Invalid dependency, missing resolver"
      end

      dependency
    end

    def initialize(
      @name : String,
      @resolver : String? = nil, @url : String? = nil,
      @version : String? = nil,
      @branch : String? = nil, @tag : String? = nil, @commit : String? = nil,
      @unmapped : Hash(String, YAML::Any) = Hash(String, YAML::Any).new
    )
    end

    def version
      version? || "*"
    end

    def version?
      if version = @version
        version
      elsif tag =~ VERSION_TAG
        $1
      end
    end

    def prerelease?
      Versions.prerelease? version
    end

    def refs
      branch || tag || commit
    end

    def to_human_requirement
      if version = self.version?
        version
      elsif branch = self.branch
        "branch #{branch}"
      elsif tag = self.tag
        "tag #{tag}"
      elsif commit = self.commit
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
