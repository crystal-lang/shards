require "./resolver"
require "../logger"

module Shards
  abstract class VersionControlResolver < Resolver
    @@command : Bool?
    @@version : String?
    @origin_url : String?

    abstract def read_spec(version : Version) : String?
    abstract def versions_from_tags

    def available_releases : Array(Version)
      update_local_cache
      versions_from_tags
    end

    private def spec?(version)
      spec(version)
    rescue Error
    end

    def vcs_url
      source.strip
    end

    # Retry loop for version-control commands
    private def vcs_retry(err = "Failed to fetch repository", &)
      retries = 0
      loop do
        yield
        break
      rescue inner_err : Error
        retries += 1
        next if retries < 3
        Log.debug { inner_err }
        raise Error.new("#{err}: #{inner_err}")
      end
    end

    # Returns whether origin URLs have differing hosts and/or paths.
    protected def origin_changed?
      return false if origin_url == vcs_url
      return true if origin_url.nil? || vcs_url.nil?

      origin_parsed = parse_uri(origin_url)
      vcs_parsed = parse_uri(vcs_url)

      (origin_parsed.host != vcs_parsed.host) || (origin_parsed.path != vcs_parsed.path)
    end

    # Parses a URI string, with additional support for ssh+git URI schemes.
    private def parse_uri(raw_uri)
      # Need to check for file URIs early, otherwise generic parsing will fail on a colon.
      if (path = raw_uri.lchop?("file://"))
        return URI.new(scheme: "file", path: path)
      end

      # Try normal URI parsing first
      uri = URI.parse(raw_uri)
      return uri if uri.absolute? && !uri.opaque?

      # Otherwise, assume and attempt to parse the scp-style ssh URIs
      host, _, path = raw_uri.partition(':')

      if host.includes?('@')
        user, _, host = host.partition('@')
      end

      # Normalize leading slash, matching URI parsing
      unless path.starts_with?('/')
        path = '/' + path
      end

      URI.new(scheme: "ssh", host: host, path: path, user: user)
    end

    def update_local_cache
      if cloned_repository? && origin_changed?
        delete_repository
        @updated_cache = false
      end

      return if Shards.local? || @updated_cache
      Log.info { "Fetching #{vcs_url}" }

      if cloned_repository?
        # repositories cloned with shards v0.8.0 won't fetch any new remote
        # refs; we must delete them and clone again!
        if valid_repository?
          fetch_repository
        else
          delete_repository
          mirror_repository
        end
      else
        mirror_repository
      end

      @updated_cache = true
    end
  end
end
