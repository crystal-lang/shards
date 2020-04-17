module Shards
  struct VersionReq
    getter pattern : String

    def initialize(@pattern)
    end

    def prerelease?
      Versions.prerelease? @pattern
    end

    def to_s(io)
      io << pattern
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
  end

  abstract struct Ref
  end

  module Any
    extend self

    def to_s(io)
      io << "*"
    end
  end

  alias Requirement = VersionReq | Version | Ref | Any
end
