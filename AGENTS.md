# Shards Development Guidelines for AI Agents

Welcome! This document serves as the canonical operating manual, coding standard, and ground-truth reference for AI coding agents collaborating on the [crystal-lang/shards](https://github.com/crystal-lang/shards) repository.

---

## 🎯 Repository Purpose & Architecture

**Shards** is the official dependency manager for the Crystal programming language. It manages package specifications (`shard.yml`), dependency overrides (`shard.override.yml`), version locks (`shard.lock`), and package resolution via the Molinillo constraint solver.

### Architectural Subsystems

```
                                 Shards Architecture
  ┌───────────────────────────────────────────────────────────────────────────────────┐
  │                                   CLI Entrypoint                                  │
  │                      `cli.cr` (OptionParser & Subcommands)                        │
  └─────────────────────────────────────────┬─────────────────────────────────────────┘
                                            │
                      ┌─────────────────────┴─────────────────────┐
                      ▼                                           ▼
  ┌───────────────────────────────────────┐   ┌───────────────────────────────────────┐
  │           Command Pipeline            │   │          Dependency Solving           │
  │   `commands/` (Install, Update,       │   │        `molinillo_solver.cr`          │
  │    Check, Build, Run, Lock, Outdated, │◄──┤   • Molinillo SpecificationProvider   │
  │    Prune, Init, List, Version)        │   │   • Parallel cache prefetching        │
  │   `script.cr` (Lifecycle scripts)     │   │   • Topological sort (`tsort`)        │
  └───────────────────┬───────────────────┘   └───────────────────┬───────────────────┘
                      │                                           │
                      ▼                                           ▼
  ┌───────────────────────────────────────┐   ┌───────────────────────────────────────┐
  │         Manifest & Metadata           │   │           Resolvers Engine            │
  │   `spec.cr` (`shard.yml` parser)      │   │   `resolvers/resolver.cr` (Base)      │
  │   `lock.cr` (`shard.lock` v1.0/2.0)   │   │   • `git.cr` (GitHub, GitLab, etc.)   │
  │   `override.cr` (`shard.override.yml`)│   │   • `path.cr` (Local symlinks)        │
  │   `package.cr` (Installation entity)  │   │   • `fossil.cr` & `hg.cr` (VCS)       │
  │   `versions.cr` (Natural sort/SemVer) │   │   • `crystal.cr` (Compiler version)   │
  │   `info.cr` (`.shards.info` state)    │   │                                       │
  └───────────────────────────────────────┴───┴───────────────────────────────────────┘
```

---

## 🛑 General Mandates & Workflow

### Deterministic Collaboration Protocol (DCP)
All development work must follow this strict three-phase process:
1. **Context Before Code**: Ingest relevant commit history, existing PRs, and architectural consensus before making modifications.
2. **Invariants First**: Write an isolated, failing spec proving any bug or edge case before submitting a minimal, targeted fix.
3. **Strict Ecosystem Compliance**: Adhere 100% to codebase layout, formatting (`crystal tool format`), and test macros. Zero workspace pollution.

---

## ⚡️ Statically Typed & Compiled Safety Rules

### 1. Nil Safety & Type Narrowing
> [!WARNING]
> Never use `.not_nil!` to silence the compiler.

Use type narrowing techniques (`if`, `case`, `try`, or `getter!`) to handle union and optional types safely. For collection getters, use lazy initialization:
```crystal
def dependencies : Array(Dependency)
  @dependencies ||= [] of Dependency
end
```

### 2. Process Spawning & VCS Security
* **No Raw Shell Invocations**: Never execute VCS commands via `shell: true`. Parse commands with `Process.parse_arguments` and pass argument arrays to `Process.run`.
* **Credential Prompt Suppression**: Pass `-c core.askPass=true` during Git mirror clones to prevent hanging on interactive prompts in CI.
* **Lifecycle Script Scoping**: Postinstall scripts (`Shards::Script`) intentionally use `shell: true` with sandboxed directory scoping (`Dir.cd(install_path)`).

### 3. Cross-Platform Path Sanitization
* Always expand paths and enforce strict prefix containment with backslash normalization on Windows:
```crystal
path_str = Path[Shards.install_path, name].expand.to_s
base_path_str = Path[Shards.install_path].expand.to_s

{% if flag?(:win32) %}
  path_str = path_str.tr('\\', '/')
  base_path_str = base_path_str.tr('\\', '/')
{% end %}

unless path_str == base_path_str || path_str.starts_with?("#{base_path_str}/")
  raise Shards::Error.new("Invalid package name: path traversal detected")
end
```

### 4. Streaming YAML Parsing & Duplicate Key Protection
* Parse manifest YAML using `YAML::PullParser` with `each_in_mapping` and `each_in_sequence`.
* Guard every attribute against YAML duplicate-key attacks using `check_duplicate`:
```crystal
when "name"
  check_duplicate(@name, "name", line, column)
  @name = pull.read_scalar
```

### 5. Windows Symlink Privileges
* Any command creating symlinks or interacting with `lib/` must invoke `check_symlink_privilege` to verify Developer Mode or `SeCreateSymbolicLinkPrivilege`.

---

## 📦 Modular Domain Skills (`.agents/skills/`)

Detailed architectural rules, code patterns, and best practices are modularized into domain skills:

| Domain Skill | Directory | Scope & Responsibilities |
| :--- | :--- | :--- |
| **`shards-manifest`** | [`.agents/skills/shards-manifest/SKILL.md`](.agents/skills/shards-manifest/SKILL.md) | `shard.yml`, `shard.override.yml`, `shard.lock` (v1.0 & v2.0), `.shards.info`, `Spec`, `Package`, `Target`, and `YAML::PullParser` stream mapping. |
| **`shards-resolvers`** | [`.agents/skills/shards-resolvers/SKILL.md`](.agents/skills/shards-resolvers/SKILL.md) | Resolver registry, Git mirror caching (`--mirror`), Path, Fossil, Mercurial (Hg), and Crystal resolvers, with safe process argument vectors. |
| **`shards-solver`** | [`.agents/skills/shards-solver/SKILL.md`](.agents/skills/shards-solver/SKILL.md) | Molinillo backtracking solver, SemVer natural sort, `VersionReq` (`~>`, `>=`, `=`), concurrent prefetching with fiber channels, and topological sort. |
| **`shards-commands`** | [`.agents/skills/shards-commands/SKILL.md`](.agents/skills/shards-commands/SKILL.md) | CLI commands (`install`, `update`, `check`, `build`, `run`, `prune`, etc.), lifecycle scripts (`Shards::Script`), and Windows Developer Mode privileges. |
| **Skills Catalog** | [`.agents/skills/index.md`](.agents/skills/index.md) | Central navigation and architectural principles for all domain skills. |

---

## 🛠 Repository Workflows & Testing

### Building & Running Specs
```bash
# Run full test suite
crystal spec

# Run targeted unit specs
crystal spec spec/unit/version_spec.cr
crystal spec spec/unit/target_spec.cr
crystal spec spec/unit/errors_spec.cr

# Run integration specs
crystal spec spec/integration/install_spec.cr
```

---

## 🔄 In-Tree Skill Maintenance & Evolution

Because the AI agent skills live directly in-tree inside `.agents/skills/`, they are first-class source artifacts that evolve commit-by-commit alongside Shards:

1. **Atomic PR Updates**: Whenever a pull request adds or modifies a manifest attribute (`src/spec.cr`), resolver engine (`src/resolvers/`), solver heuristic (`src/molinillo_solver.cr`), or CLI command (`src/commands/`), the author or agent should update the corresponding domain skill in `.agents/skills/` within the same pull request.
2. **Empirical Spec Verification**: Code snippets and patterns documented in `.agents/skills/` must always be verified by running the test suite (`crystal spec`).
3. **No Standalone Versioning**: The skills share the repository's native version and release tags. When Shards cuts a new release, the skills are automatically included and synchronized.

