# Crystal Shards

Dependency manager for the [Crystal language](https://crystal-lang.org).

Crystal applications and libraries are expected to have a `shard.yml` file
at their root looking like this:

```yaml
name: shards
version: 0.1.0

dependencies:
  openssl:
    github: datanoise/openssl.cr
    branch: master

development_dependencies:
  minitest:
    git: https://github.com/ysbaddaden/minitest.cr.git
    version: ~> 1.0.0

license: MIT
```

When libraries are installed from Git repositories, the repository is expected
to have version tags following the [semver](http://semver.org/) format,
prefixed with a `v`. Examples: `v1.2.3` or `v2.0.0-rc1`.

Please see the [SPEC](https://github.com/ysbaddaden/shards/blob/master/README.md)
for more details about the `shard.yml` format.

## About

Shards will eventually supersede the current "crystal deps" command and be
distributed along with the Crystal distribution.

Shards already resolves and installs dependencies recursively and work is
undergoing to generate a lock file for indempotent installs across different
computers.

Shards doesn't resolve conflicts when it happens that a nested dependency
version is incompatible with a top dependency, yet.

## Requirements

* Crystal >= 0.7.7

## License

Licensed under the Apache License, Version 2.0. See LICENSE for details.
