require "file_utils"
require "./command"

module Shards
  module Commands
    class Prune < Command
      def run
        return unless lockfile?

        Dir[File.join(Shards.install_path, "*")].each do |path|
          next unless File.directory?(path)
          name = File.basename(path)

          if locks.shards.none? { |d| d.name == name }
            Log.debug { "rm -rf '#{Process.quote(path)}'" }
            FileUtils.rm_rf(path)

            Shards.info.installed.delete(name)
            Log.info { "Pruned #{File.join(File.basename(Shards.install_path), name)}" }
          end
        end

        Shards.info.save
      end
    end
  end
end
