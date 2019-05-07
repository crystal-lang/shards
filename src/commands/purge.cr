require "./command"
require "../config"

module Shards
  module Commands
    class Purge < Command
      def run
        FileUtils.rm_r(Dir.children(Shards.cache_path))

        if Dir.empty?(Shards.cache_path)
          Shards.logger.info "Cache has been cleaned"
        else
          Shards.logger.info "Unable to verify cache has been cleaned"
        end
      end
    end
  end
end
