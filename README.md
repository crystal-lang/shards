# Crystal Shards

Dependency manager for the [Crystal language](https://crystal-lang.org).

The idea is for Crystal applications and libraries to have a `shard.yml` file
at their root looking like this:

```yaml
name: shards
version: 0.1.0

sources:
  - https://shards.crystal-lang.org/
  - https://shards.example.com/

shards:
  pg: >= 1.2.3
  memcached: *

  minitest:
    git: https://github.com/ysbaddaden/minitest.cr.git
    version: ~> 1.0.0

  openssl:
    github: datanoise/openssl.cr
    branch: master
```

Dependencies are then resolved, downloaded and installed into the `libs` folder,
ready to be required.

## Development Plan

- [x] step 1: install/update dependencies
  - [x] clone from Git repositories (with github shortener)
  - [x] copy/link from local path

- [ ] step 2: resolve dependencies (dumb)
  - [x] recursively install dependencies
  - [x] list versions using Git tags (v0.0.0-{pre,rc}0)
  - [x] checkout specified versions (defaults to: latest version, then HEAD)
  - [ ] checkout specified Git branch/tag (limiting available versions)
  - [x] resolve versions, applying requirements (`*`, `>=`, `<=`, `<`, `>`, `~>`), recursively
  - [ ] lock resolved dependencies in `shards.yml.lock` (or `.shards/lock` or `.shards.lock`?)

- [ ] step 3: smarter resolver
  - [ ] resolve conflicts (when possible)

- [ ] step 4: central registry
  - [ ] multiple registries for private packages / mirrors
  - [ ] resolve dependencies by name => repository URL
  - [ ] list package versions (and their dependencies?)

## FAQ

- Why not using a Crystal file (like Ruby's Bundler or crystal deps)?

  That would be nice, since YAML (or JSON or TOML) don't play nicely with
  statically typed languages, but it would require compiling the Crystal
  source file for each and every dependency + version pairs... that would
  certainly end up ugly.

- Why YAML and not JSON or TOML?

  JSON is too noisy. TOML's spec is unstable. YAML did the job.

- Why eventually have a central registry?

  Remembering package names is simpler than remembering their package names and
  their repository URL. Also it would speed things up drastically —no more need
  to clone all repositories to resolve dependencies for example.

## Requirements

* Crystal > 0.7.2

## License

Licensed under the Apache License, Version 2.0. See LICENSE for details.
