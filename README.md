# Shards

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

Please see the [SPEC](https://github.com/ysbaddaden/shards/blob/master/SPEC.md)
for more details about the `shard.yml` format.

## About

Shards will eventually supersede the current "crystal deps" command and be
distributed along with the Crystal distribution.

Shards resolves and installs dependencies recursively and work is
undergoing to generate a lock file for indempotent installs across different
computers. Shards doesn't yet resolve conflicts when a nested dependency
version is incompatible with the requirement of a top dependency.

## Install

First of all, you need a recent Crystal compiler. Please refer to
<http://crystal-lang.org/docs/installation> for instructions for your
operating system.

You can download a statically compiled 64bit executable of Shards from the
[releases](https://github.com/ysbaddaden/shards/releases) page.

Alternatively you may download a source tarball from the same page (or
clone the repository) then run `make` —or `make release` for an optimized
build— and copy the newly generated `bin/shards` somewhere into your PATH.
A good place is `/usr/local/bin` for example.

You are now ready to create a `shard.yml` for your projects (see the
[SPEC](https://github.com/ysbaddaden/shards/blob/master/SPEC.md)).

Simply run `shards install` to install your dependencies, or
`shards --help` to list the other commands and their options.

Happy Hacking!

## Requirements

* Crystal >= 0.7.7

## License

Licensed under the Apache License, Version 2.0. See LICENSE for details.
