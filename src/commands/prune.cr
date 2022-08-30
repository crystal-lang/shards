require "file_utils"
require "./command"
require "../helpers"

module Shards
  module Commands
    class Prune < Command
      def run
        return unless lockfile?

        unless Dir.exists?(Shards.install_path)
          Log.info { "Pruned nothing, because #{File.basename(Shards.install_path)}/ does not exist" }
          return
        end

        Dir.each_child(Shards.install_path) do |name|
          path = File.join(Shards.install_path, name)
          next unless File.directory?(path)

          if locks.shards.none? { |d| d.name == name }
            Log.debug { "rm -rf '#{Process.quote(path)}'" }
            Shards::Helpers.rm_rf(path)

            Shards.info.installed.delete(name)
            Log.info { "Pruned #{File.join(File.basename(Shards.install_path), name)}" }
          end
        end

        Shards.info.save
      end
    end
  end
end
