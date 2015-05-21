module Shards
  RELEASE_VERSION = /^v?([\d\.]+)$/

  class GitResolver < Resolver
    def read_spec(version = "*")
      refs = case version
      when RELEASE_VERSION
        "v#{version}"
      when "*"
        "HEAD"
      else
        version
      end

      update_local_cache

      if file_exists?(refs, SPEC_FILENAME)
        run("git cat-file #{refs} #{SPEC_FILENAME}", capture: true).not_nil!
      else
        "name: #{dependency.name}\nversion: 0.0.0\n"
      end
    end

    def available_versions
      update_local_cache

      versions = run("git tag --list --no-column", capture: true).not_nil!
        .split("\n")
        .map { |version| $1 if version.strip =~ RELEASE_VERSION }
        .compact

      if versions.any?
        versions
      else
        ["HEAD"]
      end
    end

    def local_path
      File.join(CACHE_DIRECTORY, dependency.name)
    end

    def git_url
      dependency["git"].to_s
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
      run "git clone --mirror --quiet -- '#{git_url.gsub(/'/, "\\'")}' #{dependency.name}",
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
      files = run "git ls-tree -r --full-tree --name-only #{refs} -- #{path}", capture: true
      !files.to_s.strip.empty?
    end

    private def run(command, capture = false, path = local_path)
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
