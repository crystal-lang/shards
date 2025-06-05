require "./dependency"

module Shards
  class DependencyDefinition
    record Parts, resolver_key : String, source : String, requirement : Requirement = Any

    property dependency : Dependency
    # resolver's key and source are normalized. We preserve the key and source to be used
    # in the shard.yml file in these field. This is used to generate the shard.yml file
    # in a more human-readable way.
    property resolver_key : String
    property source : String

    def initialize(@dependency : Dependency, @resolver_key : String, @source : String)
    end

    # Used to generate the shard.yml file.
    def to_yaml(yaml : YAML::Builder)
      yaml.scalar dependency.name
      yaml.mapping do
        yaml.scalar resolver_key
        yaml.scalar source
        dependency.requirement.to_yaml(yaml)
      end
    end

    # Parse a dependency from a CLI argument
    def self.from_cli(value : String) : DependencyDefinition
      parts = parts_from_cli(value)

      # We need to check the actual shard name to create a dependency.
      # This requires getting the actual spec file from some matching version.
      resolver = Resolver.find_resolver(parts.resolver_key, "unknown", parts.source)
      version = resolver.versions_for(parts.requirement).first || raise Shards::Error.new("No versions found for dependency: #{value}")
      spec = resolver.spec(version)
      name = spec.name || raise Shards::Error.new("No name found for dependency: #{value}")

      DependencyDefinition.new(Dependency.new(name, resolver, parts.requirement), parts.resolver_key, parts.source)
    end

    # :nodoc:
    #
    # Parse the dependency from a CLI argument
    # and return the parts needed to create the proper dependency.
    #
    # Split to allow better unit testing.
    def self.parts_from_cli(value : String) : Parts
      uri = URI.parse(value)

      case scheme = uri.scheme
      when Nil
        case value
        when .starts_with?("./"), .starts_with?("../")
          Parts.new("path", Path[value].to_posix.to_s)
        when .starts_with?(".\\"), .starts_with?("..\\")
          {% if flag?(:windows) %}
            Parts.new("path", Path[value].to_posix.to_s)
          {% else %}
            raise Shards::Error.new("Invalid dependency format: #{value}")
          {% end %}
        when .starts_with?("git@")
          Parts.new("git", value)
        else
          raise Shards::Error.new("Invalid dependency format: #{value}")
        end
      when "file"
        raise Shards::Error.new("Invalid file URI: #{uri}") if !uri.host.in?(nil, "", "localhost") || uri.port || uri.user
        Parts.new("path", uri.path)
      when "https"
        if resolver_key = GitResolver::KNOWN_PROVIDERS[uri.host]?
          Parts.new(resolver_key, uri.path[1..-1].rchop(".git")) # drop first "/""
        else
          raise Shards::Error.new("Cannot determine resolver for HTTPS URI: #{value}")
        end
      else
        scheme, _, subscheme = scheme.partition('+')
        subscheme = subscheme.presence
        if Resolver.find_class(scheme)
          if uri.host.nil? || subscheme
            uri.scheme = subscheme
          end
          source = uri.to_s
          # narrow down requirement
          requirement = Any
          if source.includes?("@")
            source, version = source.split("@")
            requirement = VersionReq.new("~> #{version}")
          end

          return Parts.new(scheme, source, requirement)
        end
        raise Shards::Error.new("Invalid dependency format: #{value}")
      end
    end
  end
end
