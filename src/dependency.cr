require "./ext/yaml"
require "./requirement"

module Shards
  class Dependency
    property name : String
    property resolver : Resolver
    property requirement : Requirement

    def initialize(@name : String, @resolver : Resolver, @requirement : Requirement = Any)
    end

    def initialize(pull : YAML::PullParser, *, is_lock = false)
      @name = pull.read_scalar
      @resolver, @requirement = pull.read_mapping do
        mapping_start = pull.location
        key = pull.read_scalar
        source = pull.read_scalar
        resolver_class = Resolver.find_class(key)
        unless resolver_class
          raise YAML::ParseException.new("Unknown resolver #{key.inspect} for dependency #{@name.inspect}", *mapping_start)
        end

        res = resolver_class.find_resolver(key, name, source)
        req = res.parse_requirement(pull)
        if is_lock && req.is_a?(VersionReq)
          req = Version.new(req.pattern)
        end

        unless pull.kind.mapping_end?
          location = pull.location
          key = pull.read_scalar
          raise YAML::ParseException.new("Unknown attribute #{key.inspect} for dependency #{@name.inspect}", *location)
        end
        {res, req}
      end
    end

    def_equals @name, @resolver, @requirement

    def prerelease?
      case req = requirement
      when Version
        req.prerelease?
      when VersionReq
        req.prerelease?
      else
        false
      end
    end

    def to_human_requirement
      if version?
        version
      elsif branch
        "branch #{branch}"
      elsif tag
        "tag #{tag}"
      elsif commit
        "commit #{commit}"
      else
        "*"
      end
    end

    def to_s(io)
      io << name << " (" << requirement << ")"
    end

    def matches?(version : Version)
      case req = requirement
      when Ref
        resolver.matches_ref?(req, version)
      when Version
        req == version
      when VersionReq
        Versions.matches?(version, req)
      when Any
        true
      end
    end
  end
end
