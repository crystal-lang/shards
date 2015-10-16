require "./resolver"
require "../helpers/natural_sort"

module Shards
  RELEASE_VERSION = /^v?([\d\.]+)$/

  class GitResolver < Resolver
    # :nodoc:
    GIT_VERSION = `git --version`.strip[12 .. -1]

    # :nodoc:
    GIT_COLUMN_NEVER = Helpers::NaturalSort.sort(GIT_VERSION, "1.7.11") < 0 ? "--column=never" : ""

    def self.key
      "git"
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
                   [version_at(refs), refs]
                 else
                   capture("git tag --list #{ GIT_COLUMN_NEVER }")
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

    # FIXME: dependency.refs always take precedence when the manager should
    #        actually deal with that (?)
    def install(version = nil)
      update_local_cache
      refs = dependency.refs || git_refs(version)

      cleanup_install_directory
      Dir.mkdir_p(install_path)

      if file_exists?(refs, SPEC_FILENAME)
        run "git archive --format=tar #{refs} #{SPEC_FILENAME} | tar x -C #{escape install_path}"
      else
        File.write(File.join(install_path, "shard.yml"), read_spec(version))
      end

      # TODO: search for LICENSE* files
      if file_exists?(refs, "LICENSE")
        run "git archive --format=tar #{refs} 'LICENSE' | tar x -C #{escape install_path}"
      end

      run "git archive --format=tar --prefix= #{refs}:src/ | tar x -C #{escape install_path}"
    end

    def installed_commit_hash
      return unless installed?
      run("git log -n 1 --pretty=%H", capture: true).not_nil!.strip
    end

    def local_path
      File.join(CACHE_DIRECTORY, dependency.name)
    end

    def git_url
      dependency["git"].to_s.strip
    end

    private def git_refs(version)
      case version
      when RELEASE_VERSION
        "v#{version}"
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
    def version_at(refs)
      update_local_cache

      tags = capture("git tag --list --contains #{refs} #{ GIT_COLUMN_NEVER }")
        .split("\n")
        .map { |tag| $1 if tag =~ RELEASE_VERSION }
        .compact
      tags.first?
    end

    def refs_at(commit)
      update_local_cache

      refs = [] of String?
      refs << commit
      refs += capture("git tag --list --contains #{commit} #{ GIT_COLUMN_NEVER }").split("\n")
      refs += capture("git branch --list --contains #{commit} #{ GIT_COLUMN_NEVER }").split(" ")
      refs.compact.uniq
    end

    private def update_local_cache
      if cloned_repository? && origin_changed?
        delete_repository
        @updated_cache = false
      end

      return if !@update_cache || @updated_cache
      Shards.logger.info "Updating #{git_url}"

      if cloned_repository?
        fetch_repository
      else
        clone_repository
      end

      @updated_cache = true
    end

    private def clone_repository
      Dir.mkdir_p(CACHE_DIRECTORY) unless Dir.exists?(CACHE_DIRECTORY)
      run "git clone --mirror --quiet -- #{escape git_url} #{dependency.name}",
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
      run "rm -rf #{local_path}"
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
      # Shards.logger.debug { "cd #{path}" }

      Dir.cd(path) do
        Shards.logger.debug command

        output = capture ? MemoryIO.new : false
        error = MemoryIO.new
        status = Process.run("/bin/sh", input: MemoryIO.new(command), output: output, error: error)

        if status.success?
          output.to_s if capture
        else
          str = error.to_s
          if str.starts_with?("error: ") && (idx = str.index('\n'))
            message = str[7 ... idx]
          end
          raise Error.new("git command failed: #{ command } (#{ message })")
        end
      end
    end
  end

  register_resolver GitResolver
end
