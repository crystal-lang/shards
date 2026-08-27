---
name: shards-resolvers
description: Specialized guidance for working with Shards repository and dependency resolvers, including Git, Path, Fossil, Mercurial (Hg), and Crystal compiler resolvers, mirror caching, and secure process execution.
---

# Shards Resolvers & VCS Subsystem Domain Guide

This skill provides comprehensive architectural and operational standards for the **Shards Resolver Subsystem**. It covers the `Shards::Resolver` abstract registry pattern, remote URL normalization, local repository mirror caching (`SHARDS_CACHE_PATH`), tag/branch/commit ref resolution, and safe sub-process execution.

---

## Compatibility Matrix

| Resolver / Feature | Shards Legacy (< v0.10.0) | Shards Modern (v0.20.0+) |
| :--- | :--- | :--- |
| **Process Spawning** | Shell execution (`shell: true`) | Direct argument vector slices (`Process.parse_arguments`, `shell: false`) |
| **Git Clone Mode** | Standard shallow/full clone | Mirror clone (`--mirror`, `--quiet`, credential prompt disabled via `core.askPass=true`) |
| **Provider Shortcuts** | `github:` only | `github:`, `gitlab:`, `bitbucket:`, `codeberg:`, and generic `git:` |
| **Path Resolver** | Direct path reading | Realpath expansion (`File.expand_path(..., home: true)`) + symlink isolation |
| **VCS Engines** | Git only | Git (`GitResolver`), Fossil (`FossilResolver`), Mercurial (`HgResolver`), Path (`PathResolver`), Crystal (`CrystalResolver`) |

---

## Core Mandates

1. **Process Spawning Safety**: Never invoke VCS commands through `/bin/sh` or with `shell: true`. Always parse command lines with `Process.parse_arguments` and pass argument arrays directly to `Process.run` to eliminate shell metacharacter injection.
2. **Resolver Registry Pattern**: Always register resolvers with `Resolver.register_resolver(key, resolver_class)`. Never hardcode resolver type branching in command handlers.
3. **Scoped URL Normalization**: Canonicalize remote provider URLs (e.g. `github: user/repo` $\rightarrow$ `https://github.com/user/repo.git`) during resolver key normalization, but restrict HTTPS/suffix mutations to `KNOWN_PROVIDERS` to preserve custom enterprise Git endpoints.
4. **Mirror Repository Caching**: Cache remote Git repositories in `Shards.cache_path` using bare mirror repositories (`git clone --mirror`). Never check out working directories inside the cache path.
5. **Local Offline Mode Respect**: When `Shards.local?` is true, resolvers MUST NOT attempt network operations (`fetch` or `clone`). If a repository is missing from the local cache in offline mode, raise `Shards::Error`.

---

## Patterns from Source Code

### 1. Abstract Resolver Architecture & Registry

```crystal
module Shards
  abstract class Resolver
    getter name : String
    getter source : String

    def initialize(@name : String, @source : String)
    end

    def self.build(key : String, name : String, source : String) : self
      _, source = self.normalize_key_source(key, source)
      self.new(name, source)
    end

    def self.normalize_key_source(key : String, source : String) : {String, String}
      {key, source}
    end

    abstract def available_releases : Array(Version)
    abstract def read_spec(version : Version) : String?
    abstract def install_sources(version : Version, install_path : String) : Nil
    abstract def report_version(version : Version) : String

    def versions_for(req : Requirement) : Array(Version)
      case req
      when Version    then [req]
      when Ref        then [latest_version_for_ref(req)]
      when VersionReq then Versions.resolve(available_releases, req)
      when Any
        releases = available_releases
        releases.empty? ? [latest_version_for_ref(nil)] : releases
      else
        raise Error.new("Unexpected requirement type: #{req}")
      end
    end

    private record ResolverCacheKey, key : String, name : String, source : String
    private RESOLVER_CLASSES = {} of String => Resolver.class
    private RESOLVER_CACHE   = {} of ResolverCacheKey => Resolver

    def self.register_resolver(key : String, resolver : Resolver.class) : Nil
      RESOLVER_CLASSES[key] = resolver
    end

    def self.find_resolver(key : String, name : String, source : String) : Resolver
      resolver_class = RESOLVER_CLASSES[key]? ||
        raise Error.new("Failed can't resolve dependency #{name} (unsupported resolver #{key})")

      key, source = resolver_class.normalize_key_source(key, source)
      RESOLVER_CACHE[ResolverCacheKey.new(key, name, source)] ||= begin
        resolver_class.build(key, name, source)
      end
    end
  end
end
```

### 2. Git Resolver: Safe Mirror Clones & Scoped Normalization

```crystal
module Shards
  class GitResolver < Resolver
    def self.key
      "git"
    end

    private KNOWN_PROVIDERS = {
      "www.github.com",
      "github.com",
      "www.bitbucket.com",
      "bitbucket.com",
      "www.gitlab.com",
      "gitlab.com",
      "www.codeberg.org",
      "codeberg.org",
    }

    def self.normalize_key_source(key : String, source : String) : {String, String}
      case key
      when "git"
        uri = URI.parse(source)
        downcased_host = uri.host.try(&.downcase)
        scheme = uri.scheme.try(&.downcase)
        if scheme.in?("git", "http", "https") && downcased_host && downcased_host.in?(KNOWN_PROVIDERS)
          uri.scheme = "https"
          downcased_path = uri.path.downcase
          uri.path = downcased_path.ends_with?(".git") ? downcased_path : "#{downcased_path}.git"
          uri.host = downcased_host.lchop("www.")
          {"git", uri.to_s}
        else
          {"git", source}
        end
      when "github", "gitlab", "bitbucket"
        {"git", "https://#{key}.com/#{source.downcase}.git"}
      when "codeberg"
        {"git", "https://#{key}.org/#{source.downcase}.git"}
      else
        raise "Unknown resolver #{key}"
      end
    end

    def install_sources(version : Version, install_path : String) : Nil
      update_local_cache
      ref = git_ref(version)

      Dir.mkdir_p(install_path)
      # Extract exact ref tree directly into install path without touching cache worktree
      run "git --work-tree=#{Process.quote(install_path)} checkout #{Process.quote(ref.to_git_ref)} -- ."
    end

    private def run(command : String, path = local_path, capture = false) : String?
      if Shards.local? && !Dir.exists?(path)
        dependency_name = File.basename(path, ".git")
        raise Error.new("Missing repository cache for #{dependency_name.inspect}. Please run without --local to fetch it.")
      end
      run_in_folder(command, path, capture)
    end

    private def run_in_folder(command : String, path : String? = nil, capture = false) : String?
      args = Process.parse_arguments(command)
      output = capture ? IO::Memory.new : Process::Redirect::Close
      error = IO::Memory.new

      status = Process.run(args[0], args: args[1..], output: output, error: error, chdir: path)
      if status.success?
        output.to_s if capture
      else
        raise Error.new("Failed #{command}.\n#{error.to_s}")
      end
    end

    register_resolver "git", GitResolver
    register_resolver "github", GitResolver
    register_resolver "gitlab", GitResolver
    register_resolver "bitbucket", GitResolver
    register_resolver "codeberg", GitResolver
  end
end
```

### 3. Path Resolver: Local Filesystem Linking

```crystal
module Shards
  class PathResolver < Resolver
    def self.key
      "path"
    end

    def available_releases : Array(Version)
      [spec(nil).version]
    end

    def report_version(version : Version) : String
      "#{version.value} at #{source}"
    end

    def read_spec(version = nil) : String?
      spec_path = File.join(expanded_local_path, SPEC_FILENAME)
      if File.exists?(spec_path)
        File.read(spec_path)
      else
        raise Error.new("Missing #{SPEC_FILENAME.inspect} for #{name.inspect} at #{File.expand_path(source).inspect}")
      end
    end

    def install_sources(version, install_path) : Nil
      path = expanded_local_path
      Dir.mkdir_p(File.dirname(install_path))
      File.symlink(path, install_path)
    end

    private def expanded_local_path : String
      File.expand_path(source, home: true).tap do |path|
        raise Error.new("Failed no such path: #{path}") unless Dir.exists?(path)
      end
    end

    register_resolver "path", PathResolver
  end
end
```

---

## Best Practices

### Security & VCS Isolation
* **Disable Interactive Credential Prompts**: When executing Git clone operations in automation or CI, pass `-c core.askPass=true` to prevent child processes from hanging on interactive auth prompts.
* **Origin URL Drift Detection**: Always check `origin_changed?` before pulling into an existing cache directory. If the remote URL has changed (e.g. fork migration), delete and re-clone the bare repository.

### Resilient Retries
* Wrap network-bound fetch operations in an exponential or 3-attempt retry loop (`git_retry`) to mitigate transient network failures:
  ```crystal
  private def git_retry(err = "Failed to fetch repository", &)
    retries = 0
    loop do
      return yield
    rescue inner_err : Error
      retries += 1
      raise Error.new("#{err}: #{inner_err}") if retries >= 3
      sleep 0.5.seconds
    end
  end
  ```

---

## When to Use

Use this skill whenever you are:
1. Extending or modifying dependency resolver implementations (`GitResolver`, `PathResolver`, `FossilResolver`, `HgResolver`).
2. Implementing custom package source providers or repository mirrors.
3. Troubleshooting cache directory structures (`SHARDS_CACHE_PATH`) or VCS ref parsing.
4. Auditing sub-process argument execution safety in Shards.
