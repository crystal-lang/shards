module Shards
  class Error < ::Exception
    def initialize(message)
      super "Error #{message}"
    end
  end

  class Conflict < Error
    getter :package

    def initialize(@package)
      super "resolving #{package.name} (#{package.requirements.join(", ")})"
    end
  end
end
