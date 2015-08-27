require "./resolver"

module Shards
  RELEASE_VERSION = /^v?([\d\.]+)$/

  class GitResolver < Resolver
    def read_spec(version = "*")
      update_local_cache
      refs = git_refs(version)

      if file_exists?(refs, SPEC_FILENAME)
        capture("git show #{refs}:#{SPEC_FILENAME}")
      else
        if file_exists?(refs, "Projectfile")
          contents = capture("git show #{refs}:Projectfile")

          dependencies = Shards::Resolver
            .parse_dependencies_from_projectfile(contents)
            .map do |d|
              if d.has_key?("branch")
                "  #{d["name"]}:\n    github: #{d["github"]}\n    branch: #{d["branch"]}"
              else
                "  #{d["name"]}:\n    github: #{d["github"]}"
                end
            end

          if dependencies.any?
            dependencies = "dependencies:\n#{dependencies.join("\n")}"
          end
        end

        if version = version_at(refs)
          "name: #{dependency.name}\nversion: #{version}\n#{dependencies}"
        else
          "name: #{dependency.name}\n#{dependencies}"
        end
      end
    end

    def available_versions
      update_local_cache

      versions = if refs = dependency.refs
                   [version_at(refs), refs]
                 else
                   capture("git tag --list --no-column")
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
      elsif version =~ RELEASE_VERSION
        shard_path = File.join(install_path, "shard.yml")
        File.write(shard_path, "name: #{dependency.name}\nversion: #{version}\n")
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
    private def version_at(refs)
      tags = capture("git tag --list --contains #{refs}")
        .split("\n")
        .map { |tag| $1 if tag =~ RELEASE_VERSION }
        .compact
      tags.first?
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
    end

    private def cloned_repository?
      Dir.exists?(local_path)
    end

    private def origin_changed?
      capture("git ls-remote --get-url origin").strip != git_url
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
        output = nil
        error = nil
        Process.run("/bin/sh", ["-c", command]) do |process|
          output = process.output.read
          error = process.error.read
        end

        if $?.success?
          return output if capture
        else
          raise Error.new("git command failed: #{command}")
        end
      end
    end
  end

  register_resolver :git, GitResolver
end
