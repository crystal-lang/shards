require "uri"
require "./resolver"
require "../versions"
require "../helpers/path"

module Shards
  class GitResolver < Resolver
    @@has_git_command : Bool?
    @@git_column_never : String?
    @@git_version : String?

    @origin_url : String?

    def self.key
      "git"
    end

    protected def self.has_git_command?
      if @@has_git_command.nil?
        @@has_git_command = Process.run("command -v git", shell: true).success?
      end
      @@has_git_command
    end

    protected def self.git_version
      @@git_version ||= `git --version`.strip[12..-1]
    end

    protected def self.git_column_never
      @@git_column_never ||= Versions.compare(git_version, "1.7.11") < 0 ? "--column=never" : ""
    end

    def read_spec(version = "*")
      update_local_cache
      refs = git_refs(version)

      if file_exists?(refs, SPEC_FILENAME)
        capture("git show #{refs}:#{SPEC_FILENAME}")
      else
        raise Error.new("Missing \"#{refs}:#{SPEC_FILENAME}\" for #{dependency.name.inspect}")
      end
    end

    def specs(versions)
      specs = {} of String => Spec

      versions.each do |version|
        refs = git_refs(version)
        yaml = capture("git show #{refs}:#{SPEC_FILENAME}")
        specs[version] = Spec.from_yaml(yaml)
      rescue Error
      end

      specs
    end

    def spec?(version)
      refs = git_refs(version)
      yaml = capture("git show #{refs}:#{SPEC_FILENAME}")
      Spec.from_yaml(yaml)
    rescue Error
    end

    def available_versions
      update_local_cache

      versions = versions_from_tags

      if versions.any?
        Shards.logger.debug { "versions: #{versions.reverse.join(", ")}" }
        versions
      else
        ["HEAD"]
      end
    end

    protected def versions_from_tags(refs = nil)
      options = "--contains #{refs}" if refs

      capture("git tag --list #{options} #{GitResolver.git_column_never}")
        .split('\n')
        .compact_map { |tag| $1 if tag =~ VERSION_TAG }
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

    def install(version = nil)
      update_local_cache
      refs = version && git_refs(version) || "HEAD"

      cleanup_install_directory
      Dir.mkdir_p(install_path)

      unless file_exists?(refs, SPEC_FILENAME)
        File.write(File.join(install_path, "shard.yml"), read_spec(version))
      end

      run "git archive --format=tar --prefix= #{refs} | tar -x -f - -C #{Helpers::Path.escape(install_path)}"

      if version =~ VERSION_REFERENCE
        File.delete(sha1_path) if File.exists?(sha1_path)
      else
        File.write(sha1_path, commit_sha1_at(version))
      end
    end

    def commit_sha1_at(refs)
      capture("git log -n 1 --pretty=%H #{refs}").strip
    end

    def installed_commit_hash
      File.read(sha1_path).strip if installed? && File.exists?(sha1_path)
    end

    def sha1_path
      @sha1_path ||= File.join(Shards.install_path, "#{dependency.name}.sha1")
    end

    def local_path
      @local_path ||= begin
        uri = parse_uri(git_url)

        path = uri.path.to_s[1..-1]
        path = path.gsub('/', File::SEPARATOR) unless File::SEPARATOR == '/'
        path += ".git" unless path.ends_with?(".git")

        if host = uri.host
          File.join(Shards.cache_path, host, path)
        else
          File.join(Shards.cache_path, path)
        end
      end
    end

    def git_url
      dependency["git"].to_s.strip
    end

    private def git_refs(version)
      case version
      when VERSION_REFERENCE
        if version && version.starts_with?('v')
          version
        else
          "v#{version}"
        end
      when VERSION_AT_GIT_COMMIT
        $1
      when "*"
        "HEAD"
      else
        version || "HEAD"
      end
    end

    protected def version_at(refs)
      update_local_cache

      if spec = spec?(refs)
        spec.version
      else
        # FIXME: return the latest release tag BEFORE or AT the refs exactly, but
        #        never release tags AFTER the refs
        versions_from_tags(refs).first?
      end
    end

    private def refs_at(commit)
      update_local_cache

      refs = [] of String?
      refs << commit
      refs += capture("git tag --list --contains #{commit} #{GitResolver.git_column_never}").split('\n')
      refs += capture("git branch --list --contains #{commit} #{GitResolver.git_column_never}").split(' ')
      refs.compact.uniq
    end

    private def update_local_cache
      if cloned_repository? && origin_changed?
        delete_repository
        @updated_cache = false
      end

      return if Shards.local? || @updated_cache
      Shards.logger.info "Fetching #{git_url}"

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
      run_in_current_folder "git clone --mirror --quiet -- #{Helpers::Path.escape(git_url)} #{local_path}"
    rescue Error
      raise Error.new("Failed to clone #{git_url}")
    end

    private def fetch_repository
      run "git fetch --all --quiet"
    rescue Error
      raise Error.new("Failed to update #{git_url}")
    end

    private def delete_repository
      Shards.logger.debug "rm -rf '#{local_path}'"
      FileUtils.rm_rf(local_path)
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

    private def file_exists?(refs, path)
      files = capture("git ls-tree -r --full-tree --name-only #{refs} -- #{path}")
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

      Shards.logger.debug command

      output = capture ? IO::Memory.new : Process::Redirect::Close
      error = IO::Memory.new
      status = Process.run("/bin/sh", input: IO::Memory.new(command), output: output, error: error)

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
  end

  register_resolver GitResolver
end
