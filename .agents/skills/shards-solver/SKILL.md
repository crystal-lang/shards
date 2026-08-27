---
name: shards-solver
description: Specialized guidance for working with Shards dependency resolution algorithms, Molinillo solver integration, SemVer requirement matching, natural version sorting, and parallel repository cache prefetching.
---

# Shards Dependency Solving & Version Resolution Domain Guide

This skill provides comprehensive architectural and operational standards for the **Shards Dependency Resolution Subsystem**. It covers the `MolinilloSolver` implementation of Molinillo's `SpecificationProvider` and `UI` interfaces, SemVer natural version sorting, `VersionReq` operator evaluation (`~>`, `>=`, `=`), dependency graph topological sorting (`tsort`), and parallel Git cache prefetching across fiber worker pools.

---

## Compatibility Matrix

| Feature / Algorithm | Shards Legacy (< v0.10.0) | Shards Modern (v0.20.0+) |
| :--- | :--- | :--- |
| **Dependency Algorithm** | Naive recursive traversal | Molinillo backtracking constraint solver with dependency graph |
| **Version Parsing** | Heavy regular expression allocation | Direct UTF-8 byte scanning (`next_non_alphanumeric`, `split_chars_digits`) |
| **Requirement Caching** | Re-parsed per candidate comparison | Cached `VersionReq::Condition` records with typed `Op` enums |
| **Cache Prefetching** | Sequential network clones | Concurrent fiber pool (`Channel(Exception?)` + `Shards.jobs` concurrency gate) |
| **Lockfile Integration** | Overwritten indiscriminately | Conservative locked vertex preservation during `shards install` |
| **Topological Sort** | Array reverse indexing | Formal DFS-based graph topological sort (`tsort`) |

---

## Core Mandates

1. **Conservative Locked State Preservation**: During `shards install`, the solver must add all existing `shard.lock` vertices to the base dependency graph. Never upgrade locked dependencies unless explicitly requested via `shards update`.
2. **Deterministic Topological Sorting**: Packages returned by `MolinilloSolver#solve` MUST be sorted in reverse topological order (transitive dependencies first). This guarantees that child dependencies are installed before parents and postinstall scripts have access to all transitive dependencies.
3. **Pessimistic Version Matching (`~>`)**: Approximate version constraints must pin the major/minor component: `~> 1.2.3` matches `>= 1.2.3` and `< 1.3.0`; `~> 1.2` matches `>= 1.2.0` and `< 2.0.0`.
4. **Non-Allocating Byte Scanners**: When comparing versions or parsing segments in `Shards::Versions`, avoid regex compilation or string allocations in hot loops. Use byte slices and character predicates (`ascii_alphanumeric?`, `ascii_number?`).
5. **Parallel Prefetch Concurrency**: Concurrency during `prefetch_local_caches` must be strictly bounded by `Shards.jobs` (default 8) using fiber channels and atomic counters to prevent socket/file descriptor exhaustion.

---

## Patterns from Source Code

### 1. Molinillo Solver Implementation

```crystal
require "molinillo"

module Shards
  class MolinilloSolver
    setter locks : Array(Package)?
    @prereleases : Bool
    @development : Bool = true

    include Molinillo::SpecificationProvider(Shards::Dependency, Shards::Spec)
    include Molinillo::UI

    def initialize(@spec : Spec, @override : Override? = nil, *, prereleases = false)
      @prereleases = prereleases
    end

    def prepare(@development = true) : Nil
    end

    def solve : Array(Package)
      deps = @development ? (@spec.dependencies + @spec.development_dependencies) : @spec.dependencies
      deps = apply_overrides(deps)

      # 1. Prefetch remote caches in parallel before running solver
      prefetch_local_caches(deps)

      # 2. Build base graph from locks if available (conservative resolution)
      base = Molinillo::DependencyGraph(Dependency, Dependency).new
      if locks = @locks
        lock_index = locks.to_h { |d| {d.name, d} }
        add_lock(base, lock_index, deps)
      end

      # 3. Resolve graph via Molinillo
      result = Molinillo::Resolver(Dependency, Spec)
        .new(self, self)
        .resolve(deps, base)

      # 4. Topologically sort vertices (transitive dependencies first)
      packages = [] of Package
      tsort(result).each do |vertex|
        next unless vertex.payload
        spec = vertex.payload.as?(Spec) || raise "BUG: payload not a Spec"
        next if spec.name == "crystal"

        resolver = spec.resolver || raise "BUG: Spec has no resolver"
        packages << Package.new(spec.name, resolver, spec.version, !on_override(spec).nil?)
      end

      packages
    end

    private def tsort(graph) : Array(Molinillo::DependencyGraph::Vertex(Dependency, Spec))
      sorted_vertices = typeof(graph.vertices).new
      graph.vertices.values.each do |vertex|
        tsort_visit(vertex, sorted_vertices) if vertex.incoming_edges.empty?
      end
      sorted_vertices.values
    end

    private def tsort_visit(vertex, sorted_vertices) : Nil
      vertex.successors.each do |succ|
        tsort_visit(succ, sorted_vertices) unless sorted_vertices.has_key?(succ.name)
      end
      sorted_vertices[vertex.name] = vertex
    end
  end
end
```

### 2. Bounded Concurrent Cache Prefetching

```crystal
private def prefetch_local_caches(deps : Array(Dependency)) : Nil
  return unless Shards.jobs > 1

  count = 0
  active = Atomic.new(0)
  ch = Channel(Exception?).new(deps.size + 1)

  deps.each do |dep|
    count += 1
    active.add(1)
    while active.get > Shards.jobs
      sleep 0.05.seconds
    end

    spawn do
      begin
        Log.with_context do
          Log.context.set package: dep.name
          dep.resolver.update_local_cache if dep.resolver.is_a?(GitResolver)
        end
        ch.send(nil)
      rescue ex : Exception
        ch.send(ex)
      ensure
        active.sub(1)
      end
    end
  end

  count.times do
    if err = ch.receive
      raise err
    end
  end
end
```

### 3. Natural Version Sorting & Prerelease Boundary Comparison

```crystal
module Shards::Versions
  def self.compare(a : String, b : String) : Int32
    return 0 if a == b

    a_segment = Segment.new(a)
    b_segment = Segment.new(b)

    loop do
      a_segment.next
      b_segment.next

      # Accept unbalanced version numbers ("1.0" == "1.0.0.0", "1.0" < "1.0.1")
      if a_segment.empty?
        b_segment.only_zeroes? { return b_segment.prerelease? ? -1 : 1 }
        return 0
      end

      if b_segment.empty?
        a_segment.only_zeroes? { return a_segment.prerelease? ? 1 : -1 }
        return 0
      end

      a_num = a_segment.to_i?
      b_num = b_segment.to_i?

      ret = if a_num && b_num
              b_num <=> a_num # Compare numbers for natural ordering
            elsif a_num
              # b is preliminary version
              a_segment.only_zeroes? do
                return b_segment <=> a_segment if a_segment.prerelease?
                return -1
              end
              return -1
            elsif b_num
              # a is preliminary version
              b_segment.only_zeroes? do
                return b_segment <=> a_segment if b_segment.prerelease?
                return 1
              end
              return 1
            else
              b_segment <=> a_segment
            end

      return ret unless ret == 0
    end
  end
end
```

---

## Best Practices

### Resolving Version Conflicts
* When Molinillo fails to resolve a dependency graph due to conflicting version constraints, catch `Molinillo::ResolverError` in the command layer and wrap it into a structured `Shards::Conflict` error displaying all competing requirement bounds.
* Always check `CrystalResolver` compiler compatibility requirements (`MolinilloSolver.crystal_version_req`) after solving to warn users of incompatible Crystal versions.

---

## When to Use

Use this skill whenever you are:
1. Debugging or modifying the dependency resolution algorithm in `MolinilloSolver`.
2. Working with version requirement operators, SemVer comparisons, or natural sorting logic in `Shards::Versions`.
3. Optimizing repository prefetching concurrency and channel communication.
4. Implementing dependency graph traversals or conflict resolution diagnostics.
