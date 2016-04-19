require "colorize"
require "./command"
require "../registry/client"

module Shards
  module Commands
    class Search < Command
      def run(query)
        client = Registry::Client.new
        shards = client.search(query)

        if shards.as_a.any?
          puts "Search results:\n\n"

          shards.each do |shard|
            puts "    #{ shard["name"].colorize(:cyan) } #{ shard["url"] }"
          end
        else
          puts "No results."
        end
      end
    end
  end
end
