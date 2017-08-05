require "./command"
require "../file_utils"

module Shards
  module Commands
    class Prune < Command
      def run(*args)
        return unless lockfile?
        locks = Lock.from_file(lockfile_path)

        Dir[File.join(Shards.install_path, "*")].each do |path|
          next unless Dir.exists?(path)
          name = File.basename(path)

          if locks.none? { |d| d.name == name }
            FileUtils.rm_rf(path)
            Shards.logger.info "Pruned #{File.join(File.basename(Shards.install_path), name)}"
          end
        end
      end
    end
  end
end
