require "file_utils"
require "./command"
require "../helpers"

module Shards
  module Commands
    class Prune < Command
      def run
        return unless lockfile? && Dir.exists?(Shards.install_path)

        Dir.each_child(Shards.install_path) do |name|
          path = File.join(Shards.install_path, name)
          next unless File.directory?(path)

          if locks.shards.none? { |d| d.name == name }
            Log.with_context do
              Log.context.set package: name
              Log.debug { "rm -rf '#{Process.quote(path)}'" }
              Shards::Helpers.rm_rf(path)

              Shards.info.installed.delete(name)
              Log.info { "Pruned #{File.join(File.basename(Shards.install_path), name)}" }
            end
          end
        end

        Shards.info.save
      end
    end
  end
end
