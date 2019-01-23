require "file_utils"
require "./command"
require "../helpers/path"

module Shards
  module Commands
    class Prune < Command
      def run(*args)
        return unless lockfile?

        Dir[File.join(Shards.install_path, "*")].each do |path|
          next unless Dir.exists?(path)
          name = File.basename(path)

          if locks.none? { |d| d.name == name }
            Shards.logger.debug "rm -rf '#{Helpers::Path.escape(path)}'"
            FileUtils.rm_rf(path)
            Shards.logger.info "Pruned #{File.join(File.basename(Shards.install_path), name)}"
          end
        end
      end
    end
  end
end
