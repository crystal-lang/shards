require "uri"
require "./resolver"
require "../versions"
require "../logger"
require "../helpers"

module Shards
  abstract struct HgRef < Ref
    def full_info
      to_s
    end
  end

  struct HgBranchRef < HgRef
    def initialize(@branch : String)
    end

    def to_hg_ref
      @branch
    end

    def to_hg_revset
      "branch(\"#{@branch}\") and head()"
    end

    def to_s(io)
      io << "branch " << @branch
    end

    def to_yaml(yaml)
      yaml.scalar "branch"
      yaml.scalar @branch
    end
  end

  struct HgBookmarkRef < HgRef
    def initialize(@bookmark : String)
    end

    def to_hg_ref
      @bookmark
    end

    def to_hg_revset
      "bookmark(\"#{@bookmark}\")"
    end

    def to_s(io)
      io << "bookmark " << @bookmark
    end

    def to_yaml(yaml)
      yaml.scalar "bookmark"
      yaml.scalar @bookmark
    end
  end

  struct HgTagRef < HgRef
    def initialize(@tag : String)
    end

    def to_hg_ref
      @tag
    end

    def to_hg_revset
      "tag(\"#{@tag}\")"
    end

    def to_s(io)
      io << "tag " << @tag
    end

    def to_yaml(yaml)
      yaml.scalar "tag"
      yaml.scalar @tag
    end
  end

  struct HgCommitRef < HgRef
    getter commit : String

    def initialize(@commit : String)
    end

    def =~(other : HgCommitRef)
      commit.starts_with?(other.commit) || other.commit.starts_with?(commit)
    end

    def to_hg_ref
      @commit
    end

    def to_hg_revset
      @commit
    end

    def to_s(io)
      io << "commit " << @commit[0...7]
    end

    def full_info
      "commit #{@commit}"
    end

    def to_yaml(yaml)
      yaml.scalar "commit"
      yaml.scalar @commit
    end
  end

  struct HgCurrentRef < HgRef
    def to_hg_revset
      "."
    end

    def to_hg_ref
      "."
    end

    def to_s(io)
      io << "current"
    end

    def to_yaml(yaml)
      raise NotImplementedError.new("HgCurrentRef is for internal use only")
    end
  end

  class HgResolver < Resolver
    @@has_hg_command : Bool?
    @@hg_version : String?
    @@hg_process : Process | Bool | Nil

    @origin_url : String?

    def self.key
      "hg"
    end

    def self.normalize_key_source(key : String, source : String) : {String, String}
      case key
      when "hg"
        {"hg", source}
      else
        raise "Unknown resolver #{key}"
      end
    end

    protected def self.has_hg_command?
      if @@has_hg_command.nil?
        @@has_hg_command = (Process.run("hg", ["--version"]).success? rescue false)
      end
      @@has_hg_command
    end

    protected def self.hg_version
      @@hg_version ||= hg("--version")[/\(version\s+([^)]*)\)/, 1]
    end

    def read_spec(version : Version) : String?
      update_local_cache
      ref = hg_ref(version)

      if file_exists?(ref, SPEC_FILENAME)
        capture_hg("cat", "-r", ref.to_hg_revset, SPEC_FILENAME)
      else
        Log.debug { "Missing \"#{SPEC_FILENAME}\" for #{name.inspect} at #{ref}" }
        nil
      end
    end

    private def spec_at_ref(ref : HgRef) : Spec?
      update_local_cache
      begin
        if file_exists?(ref, SPEC_FILENAME)
          spec_yaml = capture_hg("cat", "-r", ref.to_hg_revset, SPEC_FILENAME)
          Spec.from_yaml(spec_yaml)
        end
      rescue Error
        nil
      end
    end

    private def spec?(version)
      spec(version)
    rescue Error
    end

    def available_releases : Array(Version)
      update_local_cache
      versions_from_tags
    end

    def latest_version_for_ref(ref : HgRef?) : Version
      update_local_cache
      ref ||= HgCurrentRef.new
      begin
        commit = commit_sha1_at(ref)
      rescue Error
        raise Error.new "Could not find #{ref.full_info} for shard #{name.inspect} in the repository #{source}"
      end

      if spec = spec_at_ref(ref)
        Version.new "#{spec.version.value}+hg.commit.#{commit}"
      else
        raise Error.new "No #{SPEC_FILENAME} was found for shard #{name.inspect} at commit #{commit}"
      end
    end

    def matches_ref?(ref : HgRef, version : Version)
      case ref
      when HgCommitRef
        ref =~ hg_ref(version)
      when HgBranchRef, HgBookmarkRef, HgCurrentRef
        # TODO: check if version is the branch
        version.has_metadata?
      else
        # TODO: check branch and tags
        true
      end
    end

    protected def versions_from_tags
      capture_hg("tags", "--template", "{tag}\\n")
        .lines
        .sort!
        .compact_map { |tag| Version.new($1) if tag =~ VERSION_TAG }
    end

    def install_sources(version : Version, install_path : String)
      update_local_cache
      ref = hg_ref(version)

      FileUtils.rm_r(install_path) if File.exists?(install_path)
      Dir.mkdir_p(install_path)
      run_hg "clone", "--quiet", "-u", ref.to_hg_ref, local_path, install_path, path: nil
    end

    def commit_sha1_at(ref : HgRef)
      capture_hg("log", "-r", ref.to_hg_revset, "--template", "{node}").strip
    end

    def local_path
      @local_path ||= begin
        uri = parse_uri(hg_url)

        path = uri.path
        path = Path[path]
        # E.g. turns "c:\local\path" into "c\local\path". Or just drops the leading slash.
        if (anchor = path.anchor)
          path = Path[path.drive.to_s.rchop(":"), path.relative_to(anchor)]
        end

        if host = uri.host
          File.join(Shards.cache_path, host, path)
        else
          File.join(Shards.cache_path, path)
        end
      end
    end

    def hg_url
      source.strip
    end

    def parse_requirement(params : Hash(String, String)) : Requirement
      params.each do |key, value|
        case key
        when "branch"
          return HgBranchRef.new value
        when "bookmark"
          return HgBookmarkRef.new value
        when "tag"
          return HgTagRef.new value
        when "commit"
          return HgCommitRef.new value
        end
      end

      super
    end

    record HgVersion, value : String, commit : String? = nil

    private def parse_hg_version(version : Version) : HgVersion
      case version.value
      when VERSION_REFERENCE
        HgVersion.new version.value
      when VERSION_AT_HG_COMMIT
        HgVersion.new $1, $2
      else
        raise Error.new("Invalid version for hg resolver: #{version}")
      end
    end

    private def hg_ref(version : Version) : HgRef
      hg_version = parse_hg_version(version)
      if commit = hg_version.commit
        HgCommitRef.new commit
      else
        HgTagRef.new "v#{hg_version.value}"
      end
    end

    private def update_local_cache
      if cloned_repository? && origin_changed?
        delete_repository
        @updated_cache = false
      end

      return if Shards.local? || @updated_cache
      Log.info { "Fetching #{hg_url}" }

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

    private def mirror_repository
      path = local_path
      FileUtils.rm_r(path) if File.exists?(path)
      Dir.mkdir_p(path)

      source = hg_url
      # Remove a "file://" from the beginning, otherwise the path might be invalid
      # on Windows.
      source = source.lchop("file://")

      hg_retry(err: "Failed to clone #{source}") do
        # We checkout the working directory so that "." is meaningful.
        #
        # An alternative would be to use the `@` bookmark, but only as long
        # as nothing new is committed.
        run_hg "clone", source, path, path: nil
      end
    end

    private def fetch_repository
      hg_retry(err: "Failed to update #{hg_url}") do
        run_hg "pull"
      end
    end

    private def hg_retry(err = "Failed to update repository")
      retries = 0
      loop do
        return yield
      rescue ex : Error
        retries += 1
        next if retries < 3
        raise Error.new("#{err}: #{ex}")
      end
    end

    private def delete_repository
      Log.debug { "rm -rf #{Process.quote(local_path)}" }
      Shards::Helpers.rm_rf(local_path)
      @origin_url = nil
    end

    private def cloned_repository?
      Dir.exists?(local_path)
    end

    private def valid_repository?
      File.exists?(File.join(local_path, ".hg", "dirstate"))
    end

    private def origin_url
      @origin_url ||= capture_hg("paths", "default").strip
    end

    # Returns whether origin URLs have differing hosts and/or paths.
    protected def origin_changed?
      return false if origin_url == hg_url
      return true if origin_url.nil? || hg_url.nil?

      origin_parsed = parse_uri(origin_url)
      hg_parsed = parse_uri(hg_url)

      (origin_parsed.host != hg_parsed.host) || (origin_parsed.path != hg_parsed.path)
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

    private def file_exists?(ref : HgRef, path)
      run_hg("files", "-r", ref.to_hg_revset, path, raise_on_fail: false)
    end

    private def capture_hg(*args, path = local_path)
      run_hg(*args, capture: true, path: path).as(String)
    end

    private def run_hg(*args, path = local_path, capture = false, raise_on_fail = true)
      if path && Shards.local? && !Dir.exists?(path)
        dependency_name = File.basename(path)
        raise Error.new("Missing repository cache for #{dependency_name.inspect}. Please run without --local to fetch it.")
      end
      HgResolver.hg(*args, path: path, capture: capture, raise_on_fail: raise_on_fail)
    end

    # Execute a hg command in the given path
    #
    # The command is run through the hg command server (if available) and
    # the command line tool otherwise. The command server is started if the
    # function is called for the first time.
    def self.hg(*args, path = Dir.current, capture = true, raise_on_fail = true)
      unless process = @@hg_process
        Log.debug { "Start Mercurial command server" }

        process = Process.new("hg serve --cmdserver pipe",
          env: {"HGENCODING" => "UTF-8"}, # enforce UTF-8 encoding
          shell: true,
          input: Process::Redirect::Pipe,
          output: Process::Redirect::Pipe,
          error: Process::Redirect::Inherit)
        @@hg_process = process

        output = process.output
        # Read the hello block
        channel = output.read_byte
        len = output.read_bytes(UInt32, IO::ByteFormat::BigEndian)
        hello = output.read_string(len)

        Log.debug { "Mercurial command server hello: #{hello}" }

        # Verify that the command server uses UTF-8 encoding
        if encoding = hello.each_line.map(&.split(": ")).find(&.[0].== "encoding")
          if encoding[1] != "UTF-8"
            # actually, this should *never* happen
            Log.warn { "Mercurial command server does not use UTF-8 encoding (#{encoding[1]}), fallback to direct command" }
            @@hg_process = true
          end
        end
      end

      # Do not use the command server but run the command directly
      if process.is_a?(Bool)
        if path
          return Dir.cd(path) { run_in_current_folder(*args, capture: capture) }
        else
          return run_in_current_folder(*args, capture: capture, raise_on_fail: raise_on_fail)
        end
      end

      # Use the command server
      cmd = String.build do |b|
        # Run the command in the specified directory
        b << "--cwd" << "\0" << path << "\0" if path
        b << args.each.join("\0")
      end

      input = process.input
      output = process.output

      input.write("runcommand\n".to_slice)
      input.write_bytes(cmd.bytesize, IO::ByteFormat::BigEndian)
      input.write(cmd.to_slice)

      result = capture ? String::Builder.new : nil
      error_msg = ""
      status = 0
      while true
        channel = output.read_byte
        len = output.read_bytes(UInt32, IO::ByteFormat::BigEndian)

        case channel
        when 'o'
          if result
            result << output.read_string(len)
          else
            output.read_string(len)
          end
        when 'e'
          error_msg = output.read_string(len)
        when 'r'
          status = output.read_bytes(Int32)
          break
        when 'L'
          raise Error.new("Mercurial process expects a line input")
        when 'I'
          raise Error.new("Mercurial process expects a block input")
        end
      end

      if status.zero?
        if result
          result.to_s
        else
          true
        end
      elsif raise_on_fail
        str = error_msg.to_s
        if str.starts_with?("abort: ") && (idx = str.index('\n'))
          message = str[7...idx]
        else
          message = str
        end
        raise Error.new("Failed hg #{args.join(" ")} (#{message}). Maybe a commit, branch, bookmark or file doesn't exist?")
      end
    end

    # Run the hg command line tool with some command line args in the current folder
    private def self.run_in_current_folder(*args, capture = false, raise_on_fail = true)
      unless HgResolver.has_hg_command?
        raise Error.new("Error missing hg command line tool. Please install Mercurial first!")
      end

      Log.debug { "hg #{args.join(" ")}" }

      output = capture ? IO::Memory.new : Process::Redirect::Close
      error = IO::Memory.new
      command = "hg #{args.each.map { |arg| Process.quote(arg) }.join(" ")}"
      status = Process.run(command, shell: true, output: output, error: error)

      if status.success?
        if capture
          output.to_s
        else
          true
        end
      elsif raise_on_fail
        str = error.to_s
        if str.starts_with?("abort: ") && (idx = str.index('\n'))
          message = str[7...idx]
        else
          message = str
        end
        raise Error.new("Failed #{command} (#{message}). Maybe a commit, branch or file doesn't exist?")
      end
    end

    def report_version(version : Version) : String
      hg_version = parse_hg_version(version)
      if commit = hg_version.commit
        "#{hg_version.value} at #{commit[0...7]}"
      else
        version.value
      end
    end

    register_resolver "hg", HgResolver
  end
end
