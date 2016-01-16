require "http/client"
require "json"
require "uri"

module Shards
  module Registry
    class Client
      class Error < Exception
      end

      class NotFound < Exception
      end

      def initialize(base_url = REGISTRY_URL)
        @base_url = URI.parse(REGISTRY_URL)
      end

      def search(query)
        get("/api/v1/shards/search", { query: query })
      end

      def shard(name)
        get("/api/v1/shards/#{ URI.escape(name) }")
      end

      def versions(name)
        get("/api/v1/shards/#{ URI.escape(name) }/versions")
      end

      def latest_version(name)
        get("/api/v1/shards/#{ URI.escape(name) }/versions/latest")
      end

      private def get(path, query = nil)
        response = HTTP::Client.get(url(path, query))

        if response.status_code < 400
          return JSON.parse(response.body)
        end

        if response.status_code == 404
          raise NotFound.new
        end

        raise Error.new("GET #{ path }: got #{ response.status_code }\n#{ response.body }")
      end

      private def url(path, query = nil)
        uri = @base_url.dup
        uri.path = path

        case query
        when String
          uri.query = query
        when Hash
          uri.query = query
            .map { |k, v| "#{ URI.escape(k.to_s) }=#{ URI.escape(v.to_s) }" }
            .join("&")
        end

        uri.to_s
      end
    end
  end
end
