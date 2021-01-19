require "uri"
require "./resolver"
require "../versions"
require "../logger"
require "../helpers"

module Shards
  abstract struct GitRef < Ref
    def full_info
      to_s
    end
  end

  struct GitBranchRef < GitRef
    def initialize(@branch : String)
    end

    def to_git_ref
      "refs/heads/#{@branch}"
    end

    def to_s(io)
      io << "branch " << @branch
    end

    def to_yaml(yaml)
      yaml.scalar "branch"
      yaml.scalar @branch
    end
  end

  struct GitTagRef < GitRef
    def initialize(@tag : String)
    end

    def to_git_ref
      "refs/tags/#{@tag}"
    end

    def to_s(io)
      io << "tag " << @tag
    end

    def to_yaml(yaml)
      yaml.scalar "tag"
      yaml.scalar @tag
    end
  end

  struct GitCommitRef < GitRef
    getter commit : String

    def initialize(@commit : String)
    end

    def =~(other : GitCommitRef)
      commit.starts_with?(other.commit) || other.commit.starts_with?(commit)
    end

    def to_git_ref
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

  struct GitHeadRef < GitRef
    def to_git_ref
      "HEAD"
    end

    def to_s(io)
      io << "HEAD"
    end

    def to_yaml(yaml)
      raise NotImplementedError.new("GitHeadRef is for internal use only")
    end
  end

  class GitResolver < Resolver
    @@has_git_command : Bool?
    @@git_column_never : String?
    @@git_version : String?

    @origin_url : String?

    def self.key
      "git"
    end

    def self.normalize_key_source(key : String, source : String) : {String, String}
      case key
      when "git"
        {"git", source}
      when "github", "bitbucket", "gitlab"
        {"git", "https://#{key}.com/#{source}.git"}
      else
        raise "Unknown resolver #{key}"
      end
    end

    protected def self.has_git_command?
      if @@has_git_command.nil?
        @@has_git_command = (Process.run("git", ["--version"]).success? rescue false)
      end
      @@has_git_command
    end

    protected def self.git_version
      @@git_version ||= `git --version`.strip[12..-1]
    end

    protected def self.git_column_never
      @@git_column_never ||= Versions.compare(git_version, "1.7.11") < 0 ? "--column=never" : ""
    end

    def read_spec(version : Version) : String?
      update_local_cache
      ref = git_ref(version)

      if file_exists?(ref, SPEC_FILENAME)
        capture("git show #{Process.quote("#{ref.to_git_ref}:#{SPEC_FILENAME}")}")
      else
        Log.debug { "Missing \"#{SPEC_FILENAME}\" for #{name.inspect} at #{ref}" }
        nil
      end
    end

    private def spec_at_ref(ref : GitRef) : Spec?
      update_local_cache
      begin
        if file_exists?(ref, SPEC_FILENAME)
          spec_yaml = capture("git show #{Process.quote("#{ref.to_git_ref}:#{SPEC_FILENAME}")}")
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

    def latest_version_for_ref(ref : GitRef?) : Version
      update_local_cache
      ref ||= GitHeadRef.new
      begin
        commit = commit_sha1_at(ref)
      rescue Error
        raise Error.new "Could not find #{ref.full_info} for shard #{name.inspect} in the repository #{source}"
      end

      if spec = spec_at_ref(ref)
        Version.new "#{spec.version.value}+git.commit.#{commit}"
      else
        raise Error.new "No #{SPEC_FILENAME} was found for shard #{name.inspect} at commit #{commit}"
      end
    end

    def matches_ref?(ref : GitRef, version : Version)
      case ref
      when GitCommitRef
        ref =~ git_ref(version)
      when GitBranchRef, GitHeadRef
        # TODO: check if version is the branch
        version.has_metadata?
      else
        # TODO: check branch and tags
        true
      end
    end

    protected def versions_from_tags
      capture("git tag --list #{GitResolver.git_column_never}")
        .split('\n')
        .compact_map { |tag| Version.new($1) if tag =~ VERSION_TAG }
    end

    def matches?(commit)
      if branch = dependency["branch"]?
        capture("git branch --list #{GitResolver.git_column_never} --contains #{commit}")
          .split('\n')
          .compact_map { |line| $1? if line =~ /^[* ] (.+)$/ }
          .includes?(branch)
      elsif tag = dependency["tag"]?
        capture("git tag --list #{GitResolver.git_column_never} --contains #{commit}")
          .split('\n')
          .includes?(tag)
      else
        !capture("git log -n 1 #{commit}").strip.empty?
      end
    end

    def install_sources(version : Version, install_path : String)
      update_local_cache
      ref = git_ref(version)

      Dir.mkdir_p(install_path)
      run "git --work-tree=#{Process.quote(install_path)} checkout #{Process.quote(ref.to_git_ref)} -- ."
    end

    def commit_sha1_at(ref : GitRef)
      capture("git log -n 1 --pretty=%H #{Process.quote(ref.to_git_ref)}").strip
    end

    def local_path
      @local_path ||= begin
        uri = parse_uri(git_url)

        path = uri.path
        path += ".git" unless path.ends_with?(".git")
        path = Path[path]
        # E.g. turns "c:\local\path.git" into "c\local\path.git". Or just drops the leading slash.
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

    def git_url
      source.strip
    end

    def parse_requirement(params : Hash(String, String)) : Requirement
      params.each do |key, value|
        case key
        when "branch"
          return GitBranchRef.new value
        when "tag"
          return GitTagRef.new value
        when "commit"
          return GitCommitRef.new value
        else
        end
      end

      super
    end

    record GitVersion, value : String, commit : String? = nil

    private def parse_git_version(version : Version) : GitVersion
      case version.value
      when VERSION_REFERENCE
        GitVersion.new version.value
      when VERSION_AT_GIT_COMMIT
        GitVersion.new $1, $2
      else
        raise Error.new("Invalid version for git resolver: #{version}")
      end
    end

    private def git_ref(version : Version) : GitRef
      git_version = parse_git_version(version)
      if commit = git_version.commit
        GitCommitRef.new commit
      else
        GitTagRef.new "v#{git_version.value}"
      end
    end

    private def update_local_cache
      if cloned_repository? && origin_changed?
        delete_repository
        @updated_cache = false
      end

      return if Shards.local? || @updated_cache
      Log.info { "Fetching #{git_url}" }

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
      # The git-config option core.askPass is set to a command that is to be
      # called when git needs to ask for credentials (for example on a 401
      # response over HTTP). Setting the command to `true` effectively
      # disables the credential prompt, because `shards install` is not to
      # be used interactively.
      # This configuration can be overriden by defining the environment
      # variable `GIT_ASKPASS`.
      git_retry(err: "Failed to clone #{git_url}") do
        run_in_current_folder "git clone -c core.askPass=true --mirror --quiet -- #{Process.quote(git_url)} #{Process.quote(local_path)}"
      end
    end

    private def fetch_repository
      git_retry(err: "Failed to update #{git_url}") do
        run "git fetch --all --quiet"
      end
    end

    private def git_retry(err = "Failed to fetch repository")
      retries = 0
      loop do
        yield
        break
      rescue Error
        retries += 1
        next if retries < 3
        raise Error.new(err)
      end
    end

    private def delete_repository
      Log.debug { "rm -rf #{Process.quote(local_path)}'" }
      Shards::Helpers.rm_rf(local_path)
      @origin_url = nil
    end

    private def cloned_repository?
      Dir.exists?(local_path)
    end

    private def valid_repository?
      File.each_line(File.join(local_path, "config")) do |line|
        return true if line =~ /mirror\s*=\s*true/
      end
      false
    end

    private def origin_url
      @origin_url ||= capture("git ls-remote --get-url origin").strip
    end

    # Returns whether origin URLs have differing hosts and/or paths.
    protected def origin_changed?
      return false if origin_url == git_url
      return true if origin_url.nil? || git_url.nil?

      origin_parsed = parse_uri(origin_url)
      git_parsed = parse_uri(git_url)

      (origin_parsed.host != git_parsed.host) || (origin_parsed.path != git_parsed.path)
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

    private def file_exists?(ref : GitRef, path)
      files = capture("git ls-tree -r --full-tree --name-only #{Process.quote(ref.to_git_ref)} -- #{Process.quote(path)}")
      !files.strip.empty?
    end

    private def capture(command, path = local_path)
      run(command, capture: true, path: local_path).not_nil!
    end

    private def run(command, path = local_path, capture = false)
      if Shards.local? && !Dir.exists?(path)
        dependency_name = File.basename(path, ".git")
        raise Error.new("Missing repository cache for #{dependency_name.inspect}. Please run without --local to fetch it.")
      end
      Dir.cd(path) do
        run_in_current_folder(command, capture)
      end
    end

    private def run_in_current_folder(command, capture = false)
      unless GitResolver.has_git_command?
        raise Error.new("Error missing git command line tool. Please install Git first!")
      end

      Log.debug { command }

      output = capture ? IO::Memory.new : Process::Redirect::Close
      error = IO::Memory.new
      status = Process.run(command, shell: true, output: output, error: error)

      if status.success?
        output.to_s if capture
      else
        str = error.to_s
        if str.starts_with?("error: ") && (idx = str.index('\n'))
          message = str[7...idx]
        end
        raise Error.new("Failed #{command} (#{message}). Maybe a commit, branch or file doesn't exist?")
      end
    end

    def report_version(version : Version) : String
      git_version = parse_git_version(version)
      if commit = git_version.commit
        "#{git_version.value} at #{commit[0...7]}"
      else
        version.value
      end
    end

    register_resolver "git", GitResolver
    register_resolver "github", GitResolver
    register_resolver "gitlab", GitResolver
    register_resolver "bitbucket", GitResolver
  end
end
