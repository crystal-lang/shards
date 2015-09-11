module Shards
  class Error < ::Exception
  end

  class Conflict < Error
    getter :package

    def initialize(@package)
      super "Error resolving #{package.name} (#{package.requirements.join(", ")})"
    end
  end

  class LockConflict < Error
    def initialize(message)
      super "Outdated #{ LOCK_FILENAME } (#{message}). Please run shards update instead."
    end
  end

  class InvalidLock < Error
    def initialize
      super "Unsupported #{ LOCK_FILENAME }. It was likely generated from a newer version of Shards."
    end
  end
end
