module Shards
  module Helpers
    module Path
      def self.escape(path)
        "'#{path.gsub(/'/, "\\'")}'"
      end
    end
  end
end
