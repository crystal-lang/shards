---
name: shards-commands
description: Specialized guidance for Shards CLI commands execution, workflow lifecycle (install, update, check, build, run, prune, outdated), lifecycle script execution, binary installation security, and Windows privilege checks.
---

# Shards CLI Commands & Execution Lifecycle Domain Guide

This skill provides comprehensive architectural and operational standards for the **Shards CLI Command Subsystem**. It covers the `Shards::Commands::Command` abstract base class, built-in command handlers (`Install`, `Update`, `Check`, `Build`, `Run`, `Lock`, `Outdated`, `Prune`, `Init`, `List`, `Version`), lifecycle scripts (`Shards::Script`), binary executable installation into `bin/`, Windows Developer Mode / symlink privileges verification, and external subcommand delegation (`shards-<cmd>`).

---

## Compatibility Matrix

| CLI Feature / Command | Shards Legacy (< v0.10.0) | Shards Modern (v0.20.0+) |
| :--- | :--- | :--- |
| **Windows Symlinks** | Unsupported or broken | Checked via `Helpers.privilege_enabled?("SeCreateSymbolicLinkPrivilege")` & Developer Mode |
| **Command Execution** | Mono-file command runner | Object-oriented command hierarchy inheriting from `Shards::Command` |
| **Subcommands** | Built-in only | Built-in + auto-delegation to PATH executables (`shards-<command>` via `Process.exec`) |
| **Logging Context** | Global unadorned logging | Structured contextual logging with `Log.with_context { Log.context.set package: name }` |
| **Target Compilation** | Raw shell out | Controlled `crystal build` invocation with flag forwarding and target directory isolation |
| **Lifecycle Scripts** | Unsandboxed execution | Scoped `Dir.cd(install_path)` with strict error capturing (`Script::Error`) |

---

## Core Mandates

1. **Strict Production / Frozen Validation**: When `Shards.frozen?` is active (e.g. in CI or `--production` mode), `Commands::Install` MUST verify that every resolved package exactly matches the locked resolver and version in `shard.lock`. If any locked version is modified or a new dependency is added, raise `Shards::LockConflict`.
2. **Binary Executable Security**: When installing executables into `bin/` (`Package#install_executables`), executable names MUST NOT contain relative path traversal components (`..`, `/`, `\`) or Windows drive colons (`:`).
3. **Lifecycle Script Execution**: Run postinstall scripts in the dependency's installation directory (`Dir.cd(install_path)`). If a script fails, clean up the incomplete installation directory and raise `Shards::Script::Error`.
4. **Windows Symlink Privilege Verification**: Any command that interacts with `lib/` or creates symlinks MUST call `check_symlink_privilege` on Windows to ensure Developer Mode is enabled or the process holds `SeCreateSymbolicLinkPrivilege`.
5. **External Subcommand Delegation**: When an unrecognized command is passed to the CLI, check `Process.find_executable("shards-#{command}")`. If found, delegate execution via `Process.exec`; otherwise, print usage synopsis and exit.

---

## Patterns from Source Code

### 1. Abstract Base Command (`src/commands/command.cr`)

```crystal
module Shards
  abstract class Command
    getter path : String
    getter spec_path : String
    getter lockfile_path : String
    getter override_path : String?

    def initialize(path)
      if File.directory?(path)
        @path = path
        @spec_path = File.join(path, SPEC_FILENAME)
      else
        @path = File.dirname(path)
        @spec_path = path
      end
      @lockfile_path = File.join(@path, LOCK_FILENAME)

      @override_path = Shards.global_override_filename
      unless @override_path
        local_override = File.join(@path, OVERRIDE_FILENAME)
        @override_path = File.exists?(local_override) ? local_override : nil
      end
    end

    def self.run(path, *args, **kwargs)
      new(path).run(*args, **kwargs)
    end

    def check_symlink_privilege : Nil
      {% if flag?(:win32) %}
        return if Shards::Helpers.developer_mode?
        return if Shards::Helpers.privilege_enabled?("SeCreateSymbolicLinkPrivilege")

        raise Shards::Error.new(<<-EOS)
        Shards needs symlinks to work. Please enable Developer Mode, or run Shards with elevated rights:
            https://learn.microsoft.com/en-us/windows/apps/get-started/enable-your-device-for-development
        EOS
      {% end %}
    end

    def touch_install_path : Nil
      Dir.mkdir_p(Shards.install_path)
      File.touch(Shards.install_path)
    end
  end
end
```

### 2. Dependency Installation Workflow (`src/commands/install.cr`)

```crystal
module Shards::Commands
  class Install < Command
    def run : Nil
      if Shards.frozen? && !lockfile?
        raise Error.new("Missing shard.lock")
      end
      check_symlink_privilege

      Log.info { "Resolving dependencies" }
      solver = MolinilloSolver.new(spec, override)
      solver.locks = locks.shards if lockfile?
      solver.prepare(development: Shards.with_development?)

      packages = handle_resolver_errors { solver.solve }
      validate(packages) if Shards.frozen?

      install(packages)

      if generate_lockfile?(packages)
        write_lockfile(packages)
      elsif !Shards.frozen?
        File.touch(lockfile_path)
      end

      touch_install_path
      check_crystal_version(packages)
    end

    private def validate(packages : Array(Package)) : Nil
      packages.each do |package|
        if lock = locks.shards.find { |d| d.name == package.name }
          if lock.resolver != package.resolver
            raise LockConflict.new("#{package.name} source changed")
          elsif lock.version != package.version
            raise LockConflict.new("#{package.name} requirements changed")
          end
        else
          raise LockConflict.new("can't install new dependency #{package.name} in production")
        end
      end
    end

    private def install(packages : Array(Package)) : Nil
      # Packages are returned in reverse topological order (transitive dependencies first)
      packages.each do |package|
        next unless install(package)
        package.postinstall
        package.install_executables
      end
    end

    private def install(package : Package) : Package?
      if package.installed?
        Log.info { "Using #{package.name} (#{package.report_version})" }
        return
      end

      Log.info { "Installing #{package.name} (#{package.report_version})" }
      package.install
      package
    end

    private def generate_lockfile?(packages) : Bool
      !Shards.frozen? && (!lockfile? || outdated_lockfile?(packages))
    end

    private def outdated_lockfile?(packages) : Bool
      return true if locks.version != Shards::Lock::CURRENT_VERSION
      return true if packages.size != locks.shards.size

      packages.index_by(&.name) != locks.shards.index_by(&.name)
    end
  end
end
```

### 3. Lifecycle Script Execution (`src/script.cr`)

```crystal
module Shards
  module Script
    class Error < Error
    end

    # Note: Shards::Script intentionally invokes `shell: true` because postinstall scripts
    # are arbitrary developer-defined shell commands in `shard.yml`. Conversely, Resolver
    # VCS invocations strictly use argument vectors to prevent injection from untrusted URLs.
    def self.run(path : String, command : String, script_name : String, dependency_name : String) : Nil
      Dir.cd(path) do
        output = IO::Memory.new
        status = Process.run(command, shell: true, output: output, error: output)
        unless status.success?
          raise Error.new("Failed #{script_name} of #{dependency_name} on #{command}:\n#{output.to_s.rstrip}")
        end
      end
    end
  end
end
```

---

## Best Practices

### Target Build & Run Safety
* In `Commands::Build`, compile targets directly using `crystal build -o bin/<target> <main>` with argument forwarding, preserving color options and debug log levels.
* In `Commands::Run`, build the specified target first and execute it via `Process.exec` on POSIX (ensuring `Log.builder.close` is called before replacing the process) and `Process.run` on Windows.

### Dependency Pruning
* When pruning unreferenced packages with `Commands::Prune`, only delete subdirectories in `lib/` that are absent from `shard.lock`. Always update `.shards.info` after pruning to prevent stale registry records.

---

## When to Use

Use this skill whenever you are:
1. Adding, modifying, or debugging Shards CLI commands (`install`, `update`, `check`, `build`, `run`, `prune`, etc.).
2. Implementing CLI options parsing or external subcommand dispatch in `src/cli.cr`.
3. Working with dependency postinstall lifecycle scripts or executable symlink installation.
4. Ensuring platform-specific compliance for Windows Developer Mode and POSIX execution semantics.
