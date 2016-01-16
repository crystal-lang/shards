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
    version: ~> 1.0.0

license: MIT
```

When libraries are installed from Git repositories, the repository is expected
to have version tags following the [semver](http://semver.org/) format,
prefixed with a `v`. Examples: `v1.2.3` or `v2.0.0-rc1`.

Please see the [SPEC](https://github.com/ysbaddaden/shards/blob/master/SPEC.md)
for more details about the `shard.yml` format.


## Install

Shards is now distributed with Crystal itself (at least in the Homebrew and
Debian/Ubuntu packages). You can invoke it with `crystal deps`.

You may download a statically compiled 64bit executable of Shards for Linux or
OS X from the [releases](https://github.com/ysbaddaden/shards/releases) page and
install it somewhere into your PATH, this version will take precedence over the
bundled version.

Alternatively you may download a source tarball from the same page (or clone the
repository) then run `make` —or `make release` for an optimized build— and copy
the newly generated `bin/shards` somewhere into your PATH. A good place is
`/usr/local/bin` for example.

You are now ready to create a `shard.yml` for your projects (see the
[SPEC](https://github.com/ysbaddaden/shards/blob/master/SPEC.md)).

Simply run `shards install` to install your dependencies, or `shards --help` to
list the other commands and their options.

Happy Hacking!


## Requirements

These requirements are only for compiling Shards.

* Crystal >= 0.10.0.

  Please refer to <http://crystal-lang.org/docs/installation> for
  instructions for your operating system.

* libyaml

  On Debian/Ubuntu Linux you may install the `libyaml-dev` package.

  On Mac OS X you may install it using homebrew with `brew install libyaml`
  then make sure to have `/usr/local/lib` in your `LIBRARY_PATH` environment
  variable (eg: `export LIBRARY_PATH="/usr/local/lib/lib:$LIBRARY_PATH"`).
  Please adjust the path per your Homebrew installation.


## License

Licensed under the Apache License, Version 2.0. See
[LICENSE]((https://github.com/ysbaddaden/shards/blob/master/LICENSE)) for
details.
