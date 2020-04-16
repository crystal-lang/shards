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
      mapping_start = pull.location
      @name = pull.read_scalar
      @resolver, @requirement = pull.read_mapping do
        resolver_data = nil
        params = Hash(String, String).new

        until pull.kind.mapping_end?
          location = pull.location
          key, value = pull.read_scalar, pull.read_scalar

          if type = Resolver.find_class(key)
            if resolver_data
              raise YAML::ParseException.new("Duplicate resolver mapping for dependency #{@name.inspect}", *location)
            else
              resolver_data = {type: type, key: key, source: value}
            end
          else
            params[key] = value
          end
        end

        unless resolver_data
          raise YAML::ParseException.new("Missing resolver for dependency #{@name.inspect}", *mapping_start)
        end

        res = resolver_data[:type].find_resolver(resolver_data[:key], @name, resolver_data[:source])
        req = res.parse_requirement(params)
        if is_lock && req.is_a?(VersionReq)
          req = Version.new(req.pattern)
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
