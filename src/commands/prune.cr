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

            version_file = "#{path}.version"
            if File.exists?(version_file)
              Log.debug { "rm '#{Helpers::Path.escape(version_file)}'" }
              File.delete(version_file)
            end

            Log.info { "Pruned #{File.join(File.basename(Shards.install_path), name)}" }
          end
        end
      end
    end
  end
end
