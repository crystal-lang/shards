# Shards

[![CI](https://github.com/crystal-lang/shards/workflows/CI/badge.svg)](https://github.com/crystal-lang/shards/actions?query=workflow%3ACI+event%3Apush+branch%3Amaster)

Dependency manager for the [Crystal language](https://crystal-lang.org).

## Usage

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
    version: ~> 0.3.1

license: MIT
```

When libraries are installed from Git repositories, the repository is expected
to have version tags following a [semver](http://semver.org/)-like format,
prefixed with a `v`. Examples: `v1.2.3`, `v2.0.0-rc1` or `v2017.04.1`.

Please see the [SPEC](docs/shard.yml.adoc) for more details about the
`shard.yml` format.


## Install

Shards is usually distributed with Crystal itself (e.g. Homebrew and Debian
packages). Alternatively, a `shards` package may be available for your system.

You can download a source tarball from the same page (or clone the repository)
then run `make release=1`and copy `bin/shards` into your `PATH`. For
example `/usr/local/bin`.

You are now ready to create a `shard.yml` for your projects (see details in
[SPEC](docs/shard.yml.adoc)). You can type `shards init` to have an example
`shard.yml` file created for your project.

Run `shards install` to install your dependencies, which will lock your
dependencies into a `shard.lock` file. You should check both `shard.yml` and
`shard.lock` into version control, so further `shards install` will always
install locked versions, achieving reproducible installations across computers.

Run `shards --help` to list other commands with their options.

Happy Hacking!

## Developers

### Requirements

These requirements are only necessary for compiling Shards.

* Crystal

  Please refer to <https://crystal-lang.org/install/> for
  instructions for your operating system.

* `molinillo`

  The shard `molinillo` needs to be in the Crystal path.
  It is available at <https://github.com/crystal-lang/crystal-molinillo>
  You can install it either with a pre-existing `shards` binary (running `shards install`)
  or just check out the repository at `lib/crystal-molinillo` (`make lib`).

* libyaml

  On Debian/Ubuntu Linux you may install the `libyaml-dev` package.

  On Mac OS X you may install it using homebrew with `brew install libyaml`
  then make sure to have `/usr/local/lib` in your `LIBRARY_PATH` environment
  variable (eg: `export LIBRARY_PATH="/usr/local/lib:$LIBRARY_PATH"`).
  Please adjust the path per your Homebrew installation.

* [asciidoctor](https://asciidoctor.org/)

  Needed for building manpages.

### Getting started

It is strongly recommended to use `make` for building shards and developing it.
The [`Makefile`](./Makefile) contains recipes for compiling and testing. Building
with `make` also ensures the source dependency `molinillo` is installed. You don't
need to take care of this yourself.

Run `make bin/shards` to build the binary.
* `release=1` for a release build (applies optimizations)
* `static=1` for static linking (only works with musl-libc)
* `debug=1` for full symbolic debug info

Run `make install` to install the binary. Target path can be adjusted with `PREFIX` (default: `PREFIX=/usr/bin`).

Run `make test` to run the test suites:
* `make test_unit` runs unit tests (`./spec/unit`)
* `make test_integration` runs integration tests (`./spec/integration`) on `bin/shards`

Run `make docs` to build the manpages.

### Devenv

This repository contains a configuration for [devenv.sh](https://devenv.sh) which
makes it easy to setup a reproducible environment with all necessary tools for
building and testing.

- Checkout the repository
- Run `devenv shell` to get a shell with development environment

A hook for [automatic shell activation](https://devenv.sh/automatic-shell-activation/)
is also included. If you have `direnv` installed, the devenv environment loads
automatically upon entering the repo folder.

## License

Licensed under the Apache License, Version 2.0. See [LICENSE](./LICENSE) for
details.
