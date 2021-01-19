# Shards

Dependency manager for the [Crystal language](http://crystal-lang.org).


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

Please see the [SPEC](https://github.com/ysbaddaden/shards/blob/master/SPEC.md)
for more details about the `shard.yml` format.


## Install

Shards is usually distributed with Crystal itself (e.g. Homebrew and Debian
packages). Alternatively, a `shards` package may be available for your system.

You can download a source tarball from the same page (or clone the repository)
then run `make release=1`and copy `bin/shards` into your `PATH`. For
example `/usr/local/bin`.

You are now ready to create a `shard.yml` for your projects (see details in
[SPEC](https://github.com/ysbaddaden/shards/blob/master/SPEC.md)). You can type
`shards init` to have an example `shard.yml` file created for your project.

Run `shards install` to install your dependencies, which will lock your
dependencies into a `shard.lock` file. You should check both `shard.yml` and
`shard.lock` into version control, so further `shards install` will always
install locked versions, achieving reproducible installations across computers.

Run `shards --help` to list other commands with their options.

Happy Hacking!


## Requirements

These requirements are only for compiling Shards.

* Crystal

  Please refer to <https://crystal-lang.org/install/> for
  instructions for your operating system.

* libyaml

  On Debian/Ubuntu Linux you may install the `libyaml-dev` package.

  On Mac OS X you may install it using homebrew with `brew install libyaml`
  then make sure to have `/usr/local/lib` in your `LIBRARY_PATH` environment
  variable (eg: `export LIBRARY_PATH="/usr/local/lib:$LIBRARY_PATH"`).
  Please adjust the path per your Homebrew installation.

* [asciidoctor](https://asciidoctor.org/)

  Needed for building manpages.


## License

Licensed under the Apache License, Version 2.0. See
[LICENSE]((https://github.com/ysbaddaden/shards/blob/master/LICENSE)) for
details.
