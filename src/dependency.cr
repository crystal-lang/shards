require "./ext/yaml"

module Shards
  class Dependency
    property name : String
    setter version : String?
    property! resolver_name : String?
    property! url : String?
    property tag : String?
    property branch : String?
    property commit : String?

    def self.new(pull : YAML::PullParser) : self
      start_pos = pull.location
      dependency = Dependency.new(pull.read_scalar)

      pull.each_in_mapping do
        mapping_start = pull.location
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
          if dependency.resolver_name?
            raise YAML::ParseException.new("Duplicate resolver mapping for dependency #{dependency.name.inspect}", *mapping_start)
          end
          dependency.resolver_name = key
          dependency.url = pull.read_scalar
        else
          # ignore unknown dependency mapping for future extensions
        end
      end

      unless dependency.url?
        raise YAML::ParseException.new("Missing resolver for dependency #{dependency.name.inspect}", *start_pos)
      end

      dependency
    end

    def self.new(name, resolver_name, url)
      new(name).tap do |dependency|
        dependency.resolver_name = resolver_name
        dependency.url = url
      end
    end

    def initialize(@name)
    end

    def_equals_and_hash @name, @version, @resolver_name, @url, @tag, @branch, @commit

    def version
      version { "*" }
    end

    def version?
      version { nil }
    end

    def version
      if version = @version
        version
      elsif tag =~ VERSION_TAG
        $1
      else
        yield
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
