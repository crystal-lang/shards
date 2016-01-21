require "./command"
require "./file_utils"

module Shards
  module Commands
    class Prune < Command
      def run
        return unless lockfile?
        locks = Lock.from_file(lockfile_path)

        Dir[File.join(INSTALL_PATH, "*")].each do |path|
          next unless Dir.exists?(path)
          name = File.basename(path)

          if locks.none? { |d| d.name == name }
            FileUtils.rm_rf(path)
            Shards.logger.info "Pruned #{File.join(File.basename(INSTALL_PATH), name)}"
          end
        end
      end
    end
  end
end
