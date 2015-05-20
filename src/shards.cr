require "./resolvers"
require "./dependencies"

shard = Shards.load_file

shard.dependencies.each do |dependency|
  p dependency.resolver
end
