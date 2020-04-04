require "./command"

module Shards
  module Commands
    class Info < Command
      def initialize(path)
        super lookup_path(path)
      end

      def display_help
        puts <<-HELP
          shards info [<command>]

          Displays information about a shard.

          Commands:
              --name          - Print the name of the shard.
              --version       - Print the version in `spec.yml`.
              -h, --help      - Print usage synopsis.

          If no command is given, a summary including name and version is printed.
          HELP
      end

      def run(args, *, stdout = STDOUT)
        case args.shift?
        when "--name"
          stdout.puts spec.name
        when "--version"
          stdout.puts spec.version
        when "--help", "-h"
          display_help
        else
          stdout.puts "   name: #{spec.name}"
          stdout.puts "version: #{spec.version}"
        end
      end

      # look up for `SPEC_FILENAME` in *path* or up
      private def lookup_path(path)
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
