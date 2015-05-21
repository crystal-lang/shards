module Shards
  class Error < ::Exception
  end

  class Conflict < Error
    getter :package

    def initialize(@package)
      super "can't resolve #{package.name} (#{package.requirements.join(", ")})"
    end
  end
end
