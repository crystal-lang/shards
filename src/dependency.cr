require "./ext/yaml"
require "./requirement"
require "./resolvers/resolver"

module Shards
  class Dependency
    property name : String
    property resolver : Resolver
    property requirement : Requirement

    def initialize(@name : String, @resolver : Resolver, @requirement : Requirement = Any)
    end

    def self.from_yaml(pull : YAML::PullParser)
      mapping_start = pull.location
      name = pull.read_scalar
      pull.read_mapping do
        resolver_data = nil
        params = Hash(String, String).new

        until pull.kind.mapping_end?
          location = pull.location
          key, value = pull.read_scalar, pull.read_scalar

          if type = Resolver.find_class(key)
            if resolver_data
              raise YAML::ParseException.new("Duplicate resolver mapping for dependency #{name.inspect}", *location)
            else
              resolver_data = {type: type, key: key, source: value}
            end
          else
            params[key] = value
          end
        end

        unless resolver_data
          raise YAML::ParseException.new("Missing resolver for dependency #{name.inspect}", *mapping_start)
        end

        resolver = resolver_data[:type].find_resolver(resolver_data[:key], name, resolver_data[:source])

        requirement = resolver.parse_requirement(params)
        Dependency.new(name, resolver, requirement)
      end
    end

    # Used to generate the shard.lock file.
    def to_yaml(yaml : YAML::Builder)
      yaml.scalar name
      yaml.mapping do
        yaml.scalar resolver.class.key
        yaml.scalar resolver.source
        requirement.to_yaml(yaml)
      end
    end

    def as_package?
      version =
        case req = @requirement
        when VersionReq then Version.new(req.to_s)
        else
          # This conversion is used to keep compatibility
          # with old versions (1.0) of lock files.
          versions = @resolver.versions_for(req)
          unless versions.size == 1
            return
          end
          versions.first
        end

      Package.new(@name, @resolver, version)
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

    private def report_requirement
      case req = requirement
      when Version
        resolver.report_version(req)
      else
        req.to_s
      end
    end

    def to_s(io)
      io << name << " (" << report_requirement << ")"
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
