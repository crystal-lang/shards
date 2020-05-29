module Shards
  struct VersionReq
    getter patterns : Array(String)

    def initialize(patterns)
      @patterns = patterns.split(',', remove_empty: true).map &.strip
    end

    def prerelease?
      patterns.any? do |pattern|
        Versions.prerelease? pattern
      end
    end

    def to_s(io)
      {% if compare_versions(Crystal::VERSION, "0.35.0-0") > 0 %}
        patterns.join(io, ", ")
      {% else %}
        patterns.join(", ", io)
      {% end %}
    end

    def to_yaml(yaml)
      yaml.scalar "version"
      yaml.scalar to_s
    end
  end

  struct Version
    getter value : String

    def initialize(@value)
    end

    def has_metadata?
      Versions.has_metadata? @value
    end

    def prerelease?
      Versions.prerelease? @value
    end

    def to_s(io)
      io << value
    end

    def to_yaml(yaml)
      yaml.scalar "version"
      yaml.scalar value
    end
  end

  abstract struct Ref
  end

  module Any
    extend self

    def to_s(io)
      io << "*"
    end

    def to_yaml(yaml)
    end
  end

  alias Requirement = VersionReq | Version | Ref | Any
end
