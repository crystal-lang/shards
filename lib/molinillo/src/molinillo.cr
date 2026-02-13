module Molinillo
  VERSION = {{ `shards version "#{__DIR__}"`.chomp.stringify }}
end

require "./molinillo/**"
