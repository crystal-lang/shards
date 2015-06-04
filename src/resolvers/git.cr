module Shards
  RELEASE_VERSION = /^v?([\d\.]+)$/

  class GitResolver < Resolver
    def read_spec(version = "*")
      refs = git_refs(version)
      update_local_cache

      if file_exists?(refs, SPEC_FILENAME)
        capture("git show #{refs}:#{SPEC_FILENAME}")
      else
        "name: #{dependency.name}\nversion: 0.0.0\n"
      end
    end

    def available_versions
      update_local_cache

      versions = capture("git tag --list --no-column")
        .split("\n")
        .map { |version| $1 if version.strip =~ RELEASE_VERSION }
        .compact

      if versions.any?
        versions
      else
        ["HEAD"]
      end
    end

    def install(version = nil)
      refs = git_refs(version)

      cleanup_install_directory
      Dir.mkdir(install_path)

      if file_exists?(refs, SPEC_FILENAME)
        run "git archive --format=tar #{refs} #{SPEC_FILENAME} | tar x -C #{escape install_path}"
      end

      # TODO: search for LICENSE* files
      if file_exists?(refs, "LICENSE")
        run "git archive --format=tar #{refs} 'LICENSE' | tar x -C #{escape install_path}"
      end

      run "git archive --format=tar --prefix= #{refs}:src/ | tar x -C #{escape install_path}"
    end

    def local_path
      File.join(CACHE_DIRECTORY, dependency.name)
    end

    def git_url
      dependency["git"].to_s
    end

    private def git_refs(version)
      case version
      when RELEASE_VERSION
        "v#{version}"
      when "*"
        "HEAD"
      else
        version
      end
    end

    private def update_local_cache
      return if @updated_cache
      Shards.logger.info "Updating #{git_url}"

      if cloned_repository?
        fetch_repository
      else
        clone_repository
      end

      @updated_cache = true
    end

    private def clone_repository
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

    private def cloned_repository?
      Dir.exists?(local_path)
    end

    private def file_exists?(refs, path)
      files = capture("git ls-tree -r --full-tree --name-only #{refs} -- #{path}")
      !files.strip.empty?
    end

    private def capture(command, path = local_path)
      run(command, capture: true, path: local_path).not_nil!
    end

    private def run(command, path = local_path, capture = false)
      Shards.logger.debug { "cd #{path}" }

      Dir.chdir(path) do
        Shards.logger.debug command
        status = Process.run("/bin/sh", input: command, output: capture)

        if status.success?
          status.output if capture
        else
          raise Error.new("git command failed: #{command}")
        end
      end
    end
  end

  register_resolver :git, GitResolver
end
