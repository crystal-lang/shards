require "./command"
require "../registry/client"

module Shards
  module Commands
    class Info < Command
      def run(name)
        client = Registry::Client.new

        shard = client.shard(name)
        latest = client.latest_version(name)

        puts "    #{ "name".colorize(:green) }: #{ shard["name"] }"
        puts "     #{ "url".colorize(:green) }: #{ shard["url"] }"
        puts " #{ "version".colorize(:green) }: #{ latest["version"] }"
        puts "#{ "released".colorize(:green) }: #{ latest["released_at"] }"

      rescue Registry::Client::NotFound
        puts "#{ "Not found:".colorize(:red) } shard #{ name } not found"
      end
    end
  end
end
