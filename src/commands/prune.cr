require "file_utils"
require "./command"
require "../helpers/path"

module Shards
  module Commands
    class Prune < Command
      def run
        return unless lockfile?

        Dir[File.join(Shards.install_path, "*")].each do |path|
          next unless File.directory?(path)
          name = File.basename(path)

          if locks.none? { |d| d.name == name }
            Log.debug { "rm -rf '#{Helpers::Path.escape(path)}'" }
            FileUtils.rm_rf(path)

            sha1 = "#{path}.sha1"
            if File.exists?(sha1)
              Log.debug { "rm '#{Helpers::Path.escape(sha1)}'" }
              File.delete(sha1)
            end

            Log.info { "Pruned #{File.join(File.basename(Shards.install_path), name)}" }
          end
        end
      end
    end
  end
end
