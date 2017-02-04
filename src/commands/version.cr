require "../helpers/versions"
require "./command"

module Shards
  module Commands
    class Version < Command
      def self.run(path, *args)
        path = lookup_path(path)
        new(path).run(*args)
      end

      def run(*args)
        puts spec.version
      end

      # look up for `SPEC_FILENAME` in *path* or up
      private def self.lookup_path(path)
        previous = nil
        current = File.expand_path(path)

        until !File.directory?(current) || current == previous
          shard_file = File.join(current, SPEC_FILENAME)
          break if File.exists?(shard_file)

          previous = current
          current = File.dirname(current)
        end

        current
      end
    end
  end
end
