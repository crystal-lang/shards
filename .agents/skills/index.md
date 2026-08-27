# Shards AI Agent Skills Catalog

This directory provides the vendor-neutral, domain-partitioned suite of AI Agent Skills for the **Crystal Shards** (`crystal-lang/shards`) package manager, developed and audited following the [Shards Knowledge Extraction Method](file:///home/renich/src/crystal/shards/METHOD.rst).

---

## Modular Domain Skills

| Skill | Directory | Scope & Domain Summary |
| :--- | :--- | :--- |
| **`shards-manifest`** | [`shards-manifest/`](file:///home/renich/src/crystal/shards/.agents/skills/shards-manifest/SKILL.md) | Parsing, validating, and generating `shard.yml`, `shard.override.yml`, `shard.lock` (v1.0 & v2.0), `.shards.info`, `Spec`, `Package`, and `Target` models. |
| **`shards-resolvers`** | [`shards-resolvers/`](file:///home/renich/src/crystal/shards/.agents/skills/shards-resolvers/SKILL.md) | Resolver registry, Git mirror caching (`--mirror`), Path, Fossil, Mercurial (Hg), and Crystal resolvers, with safe process argument vectors. |
| **`shards-solver`** | [`shards-solver/`](file:///home/renich/src/crystal/shards/.agents/skills/shards-solver/SKILL.md) | Molinillo backtracking constraint solver, SemVer natural sorting, `VersionReq` operator parsing, parallel cache prefetching with fiber channels, and topological sorting (`tsort`). |
| **`shards-commands`** | [`shards-commands/`](file:///home/renich/src/crystal/shards/.agents/skills/shards-commands/SKILL.md) | CLI commands (`install`, `update`, `check`, `build`, `run`, `lock`, `outdated`, `prune`, `init`, `list`, `version`), lifecycle scripts (`Shards::Script`), binary installation security, and Windows symlink privileges. |

---

## Architectural Principles

1. **Vendor Neutrality**: Designed to work seamlessly across all autonomous and pair programming agent ecosystems (Gemini, Claude, GitHub Copilot, Cursor, etc.).
2. **Zero Hallucination**: Grounded 100% in empirical source code verification across `src/` and the `crystal spec` suite.
3. **DRY Boundary Isolation**: Cross-cutting features reside strictly in their canonical domain skill without duplicated documentation.
4. **Standard 7-Section Skeleton**: Every skill adheres to the structured format codified in `METHOD.rst`.
