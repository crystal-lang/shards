# Crystal Shards

Dependency manager for the [Crystal language](https://crystal-lang.org).

The idea is for Crystal applications and libraries to have a `shard.yml` file
at their root looking like this:

```yaml
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

Dependencies would then be resolved, downloaded and installed into the `libs`
folder, ready to be required.

## Development Plan

- [ ] step 1: install/update dependencies
  - [ ] clone from Git repositories (with github shortener)
  - [ ] clone from Mercurial repositories (optional)
  - [ ] copy/link from local path

- [ ] step 2: resolve dependencies
  - [ ] recursively install dependencies
  - [ ] list versions using git tags (v0.0.0-{pre,rc}0)
  - [ ] checkout specified versions (defaults to the latest one)
  - [ ] resolve versions, applying requirements (`*`, `>=`, `<=`, `<`, `>`, `~>`), recursively

- [ ] step 3: central registry (dumb)
  - [ ] resolve dependencies by name => repository URL
  - [ ] multiple registries for private packages / mirrors

- [ ] step 4: central registry (smarter)
  - [ ] resolve dependencies by name => repository URL + versions (with dependencies)

## FAQ

- Why not using a Crystal file (like Ruby's Bundler or crystal deps)?

  That would be nice, since YAML (or JSON or TOML) don't play nicely with
  statically typed languages, but it would require compiling the Crystal
  source file for each and every dependency + version pairs... that would
  certainly end up ugly.

- Why YAML and not JSON or TOML?

  JSON is too verbose. TOML's spec is unstable. YAML does the job.

- Why eventually have a central registry?

  Remembering package names is simpler than remembering their package names and
  their repository URL. Also it would speed things up drastically —no more need
  to clone all repositories to resolve dependencies for example.

## License

Licensed under the Apache License, Version 2.0. See LICENSE for details.
