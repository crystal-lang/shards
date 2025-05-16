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

    # :nodoc:
    #
    # Parse the dependency from a CLI argument
    # and return the parts needed to create the proper dependency.
    #
    # Split to allow better unit testing.
    def self.parts_from_cli(value : String) : {resolver_key: String, source: String, requirement: Requirement}
      resolver_key = nil
      source = ""
      requirement = Any

      if File.directory?(value)
        resolver_key = "path"
        source = value
      end

      if value.starts_with?("https://github.com")
        resolver_key = "github"
        uri = URI.parse(value)
        source = uri.path[1..-1] # drop first "/""

        components = source.split("/")
        case components[2]?
        when "commit"
          source = "#{components[0]}/#{components[1]}"
          requirement = GitCommitRef.new(components[3])
        when "tree"
          source = "#{components[0]}/#{components[1]}"
          requirement = if components[3].starts_with?("v")
                          GitTagRef.new(components[3])
                        else
                          GitBranchRef.new(components[3..-1].join("/"))
                        end
        end
      end

      if value.starts_with?("https://gitlab.com")
        resolver_key = "gitlab"
        uri = URI.parse(value)
        source = uri.path[1..-1] # drop first "/""
      end

      if value.starts_with?("https://bitbucket.com")
        resolver_key = "bitbucket"
        uri = URI.parse(value)
        source = uri.path[1..-1] # drop first "/""
      end

      if value.starts_with?("git://")
        resolver_key = "git"
        source = value
      end

      unless resolver_key
        Resolver.resolver_keys.each do |key|
          key_schema = "#{key}:"
          if value.starts_with?(key_schema)
            resolver_key = key
            source = value.sub(key_schema, "")

            # narrow down requirement
            if source.includes?("@")
              source, version = source.split("@")
              requirement = VersionReq.new("~> #{version}")
            end

            break
          end
        end
      end

      raise Shards::Error.new("Invalid dependency format: #{value}") unless resolver_key

      {resolver_key: resolver_key, source: source, requirement: requirement}
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
