# CHANGELOG

## UNRELEASED (v0.5.1)

Fixes:
- always generate a `shard.yml` when installing legacy dependencies, see #60
- only create `libs` and `.shards` folders when required

## v0.5.0

Breaking Change:
- renamed `--no-colors` option as `--no-color` to match crystal

Features:
- nice error messages for invalid `shard.yml` files

Enhancements:
- upgraded to Crystal 0.8.0
- custom YAML parser for shard.yml compliant to the spec
- binary releases for OS X and Linux 32 bits

Fixes:
- install command fails to install dependencies on fresh projects
- check command breaks whenever a dependency is missing
- manager doesn't resolve dependencies of development dependencies recursively
- support for Git < 1.7.11 (eg: Ubuntu Precise and Debian Wheezy)
- don't generate lockfile for projects without dependencies
- don't fail when loading empty Projectfile

## v0.4.0

Features:
- lock resolved versions for indempotent installs across computers, see #27
- `--production` parameter to skip development dependencies
- postintall hook to run a command after installing a dependency, see #19

Breaking Changes:
- dropped support for custom dependency groups (but kept `development_dependencies`), see #27

Fixes:
- compatibility with Crystal 0.7.7

## v0.3.1

Fixes:
- don't install dependencies from optional groups recursively
- manager didn't install path dependencies anymore

## v0.3.0

Features:
- optional groups of dependencies, see #8
- generates default `shard.yml` from Git tags and `Projectfile` dependencies, see #6

Fixes:
- clone repository again when Git remote origin changes, see #4

## v0.2.0

Fixes:
- correctly accesses git versioned `shard.yml` files;
- correctly links/extracts the `src` folder as the `libs/<name>` folder for both
  Git and path resolvers.

## v0.1.0

Initial release.
