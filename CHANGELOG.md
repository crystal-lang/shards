# CHANGELOG

## v0.7.2

Features:
- Version command to print-out the project's version, see #147

Fixes:
- Don't consider a Git refs to be a version number, see #169
- Use installed spec for executing scripts, see #143
- Don't expect `shard.lock` when `shard.yml` has no dependencies, see #145
- Compatibility with Crystal 0.24.0 (unreleased)
- Harmonize error messages
- Correct shard.yml parse error line:column reporting

## v0.7.1

Fixes:
- correctly updates or keeps dependencies, see #107, #141
- upgrades minitest dependency so test do run

## v0.7.0

Features:
- Build command for `targets` entry in SPEC
- New Crystal search path algorithm (see breaking changes below)
- Informational `crystal` entry in SPEC
- Informational `libraries` entry in SPEC
- Shorthand for gitlab.com dependencies

Breaking Changes:
- Dependencies are installed in the `lib` directory
- Dependencies are now fully installed, instead of merely the `src` folder
- `postinstall` scripts are now executed from the root of the dependency,
  not the `src` directory

Fixes:
- crash when dependency keys were unordered
- `tar` command usage on OpenBSD
- correctly report git errors
- the update command created a lockfile for empty dependencies

## v0.6.4

Fixes:
- Compatibility with Crystal 0.19.0

## v0.6.3

Fixes:
- Compatibility with Crystal > 0.15.0
- Relative paths for path dependencies, see #99

## v0.6.2

Fixes:
- Don't crash when git binary is missing.

## v0.6.1

Fixes:
- Compatibility with Crystal > 0.11.1

## v0.6.0

Features:
- prune command to remove extraneous libs
- init command to create an initial shard.yml

Fixes:
- print details when postinstall script fails, see #84
- path resolver didn't verify the path actually existed, see #77
- recursion when shard name doesn't match dependency name, see #72

## v0.5.4

Fixes:
- Compatibility with Crystal > 0.9.1

## v0.5.3

Fixes:
- Git resolver didn't install the locked commit when using branch, tag or
  commit or just failed to install the dependency, see #65 and #67

## v0.5.2

Fixes:
- compilation on Crystal 0.9.0

## v0.5.1

Fixes:
- always generate a `shard.yml` when installing legacy dependencies, see #60
- only create `libs` and `.shards` folders when required, see #61

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
