require "./resolver"
require "../helpers/natural_sort"

module Shards
  RELEASE_VERSION = /^v?([\d\.]+)$/

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
      @@git_version ||= `git --version`.strip[12 .. -1]
    end

    protected def self.git_column_never
      @@git_column_never ||= Helpers::NaturalSort.sort(git_version, "1.7.11") < 0 ? "--column=never" : ""
    end

    def read_spec(version = "*")
      update_local_cache
      refs = git_refs(version)

      if file_exists?(refs, SPEC_FILENAME)
        capture("git show #{refs}:#{SPEC_FILENAME}")
      else
        if file_exists?(refs, "Projectfile")
          contents = capture("git show #{refs}:Projectfile")
          dependencies = parse_legacy_projectfile_to_yaml(contents)
        end

        version = version_at(refs) || DEFAULT_VERSION
        "name: #{dependency.name}\nversion: #{version}\n#{dependencies}"
      end
    end

    def available_versions
      update_local_cache

      versions = if refs = dependency.refs
                   [version_at(refs)]
                 else
                   capture("git tag --list #{ GitResolver.git_column_never }")
                     .split("\n")
                     .map { |version| $1 if version.strip =~ RELEASE_VERSION }
                 end.compact

      if versions.any?
        Shards.logger.debug { "versions: #{versions.reverse.join(", ")}" }
        versions
      else
        ["HEAD"]
      end
    end

    def matches?(commit)
      if branch = dependency["branch"]?
        capture("git branch --list #{ GitResolver.git_column_never } --contains #{ commit }")
          .split("\n")
          .compact_map { |line| $1? if line =~ /^[* ] (.+)$/ }
          .includes?(branch)
      elsif tag = dependency["tag"]?
        capture("git tag --list #{ GitResolver.git_column_never } --contains #{ commit }")
          .split("\n")
          .includes?(tag)
      else
        !capture("git log -n 1 #{ commit }").strip.empty?
      end
    end

    def install(version = nil)
      update_local_cache
      refs = version && git_refs(version) || dependency.refs || "HEAD"

      cleanup_install_directory
      Dir.mkdir_p(install_path)

      unless file_exists?(refs, SPEC_FILENAME)
        File.write(File.join(install_path, "shard.yml"), read_spec(version))
      end

      run "git archive --format=tar --prefix= #{refs} | tar -x -f - -C #{FileUtils.escape install_path}"

      if version =~ RELEASE_VERSION
        File.delete(sha1_path) if File.exists?(sha1_path)
      else
        commit = capture("git log -n 1 --pretty=%H #{ version }").strip
        File.write(sha1_path, commit)
      end
    end

    def installed_commit_hash
      File.read(sha1_path).strip if installed? && File.exists?(sha1_path)
    end

    def sha1_path
      File.join(Shards.cache_path, "#{ dependency.name }.sha1")
    end

    def local_path
      File.join(Shards.cache_path, dependency.name)
    end

    def git_url
      dependency["git"].to_s.strip
    end

    private def git_refs(version)
      case version
      when RELEASE_VERSION
        if version && version.starts_with?('v')
          version
        else
          "v#{version}"
        end
      when "*"
        "HEAD"
      else
        version || "HEAD"
      end
    end

    # TODO: first try and load shard.yml and get version from it, and eventually
    #       fallback to asking Git for release tags at commit/tag/branch.
    #
    # FIXME: return the latest release tag BEFORE or AT the refs exactly, but
    #        never release tags AFTER the refs
    private def version_at(refs)
      update_local_cache

      tags = capture("git tag --list --contains #{refs} #{ GitResolver.git_column_never }")
        .split("\n")
        .map { |tag| $1 if tag =~ RELEASE_VERSION }
        .compact
      tags.first?
    end

    private def refs_at(commit)
      update_local_cache

      refs = [] of String?
      refs << commit
      refs += capture("git tag --list --contains #{commit} #{ GitResolver.git_column_never }").split("\n")
      refs += capture("git branch --list --contains #{commit} #{ GitResolver.git_column_never }").split(" ")
      refs.compact.uniq
    end

    private def update_local_cache
      if cloned_repository? && origin_changed?
        delete_repository
        @updated_cache = false
      end

      return if !@update_cache || @updated_cache
      Shards.logger.info "Fetching #{git_url}"

      if cloned_repository?
        fetch_repository
      else
        clone_repository
      end

      @updated_cache = true
    end

    private def clone_repository
      Dir.mkdir_p(Shards.cache_path) unless Dir.exists?(Shards.cache_path)
      run "git clone --mirror --quiet -- #{FileUtils.escape git_url} #{dependency.name}",
        path: File.dirname(local_path)
    rescue Error
      raise Error.new("Failed to clone #{git_url}")
    end

    private def fetch_repository
      run "git fetch --all --quiet"
    rescue Error
      raise Error.new("Failed to update #{git_url}")
    end

    private def delete_repository
      FileUtils.rm_rf(local_path)
      @origin_url = nil
    end

    private def cloned_repository?
      Dir.exists?(local_path)
    end

    private def origin_changed?
      (@origin_url ||= capture("git ls-remote --get-url origin").strip) != git_url
    end

    private def file_exists?(refs, path)
      files = capture("git ls-tree -r --full-tree --name-only #{refs} -- #{path}")
      !files.strip.empty?
    end

    private def capture(command, path = local_path)
      run(command, capture: true, path: local_path).not_nil!
    end

    private def run(command, path = local_path, capture = false)
      unless GitResolver.has_git_command?
        raise Error.new("Error missing git command line tool. Please install Git first!")
      end

      # Shards.logger.debug { "cd #{path}" }

      Dir.cd(path) do
        Shards.logger.debug command

        output = capture ? IO::Memory.new : Process::Redirect::Close
        error = IO::Memory.new
        status = Process.run("/bin/sh", input: IO::Memory.new(command), output: output, error: error)

        if status.success?
          output.to_s if capture
        else
          str = error.to_s
          if str.starts_with?("error: ") && (idx = str.index('\n'))
            message = str[7 ... idx]
          end
          raise Error.new("Failed #{ command } (#{ message }). Maybe a commit, branch or file doesn't exist?")
        end
      end
    end
  end

  register_resolver GitResolver
end
