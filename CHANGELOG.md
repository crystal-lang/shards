# CHANGELOG

## v0.9.0.rc1 - 2019-01-11

Breaking changes:
- Dependency solver was overhauled;
- Git tag refs that match a version number are now an actual version (i.e.
  `tag: v1.0.0` is converted to `version: 1.0.0`).

Features:
- Update specified shards only, trying to keep other shards to their locked
  version if possible;
- Add `--local` argument to use the cache as-is, allowing to skip git fetches
  when you know the cache is up-to-date;
- Add the *outdated* command to list dependencies that could be updated
  (matching constraints) as well as their latest version; including pre-release
  versions on demand.
- Add the *lock* command that behaves like the *install* and *update* commands
  but that only creates a lockfile, and doesn't install anything.

Fixes:
- Transitive dependencies are now available to all installed shards, allowing
  postinstall scripts to compile any Crystal application;
- Don't consider metadata when considering a pre-release version number.

## v0.9.0.beta - 2019-01-11

Breaking changes:
- A `shard.yml` spec is now required in libraries.
- Drop support for obsolete Projectfile.

Features:
- Experimental support for prereleases. Add a letter to a version number to
  declare a pre-release. For example `1.2.3.alpha` or `1.0.0-rc1`.
- Ignore semver metadata (+abc).

Fixes:
- Approximate operator used to match invalid version numbers (e.g. `~> 0.1.0`
  wrongly matched `0.10.0`).
- Unbalanced version numbers, such as `1.0.0` and `1.0.0.1` are now correctly
  ordered and compared as `1.0.0.1 > 1.0.0`.
- Force the 'v' prefix in version tags.
- `install -t` isn't supported on macOS.

## v0.8.1 - 2018-06-17

Fixes:
- Git repositories cloned with v0.8.0 can't fetch new remote refs anymore,
  which totally broke the `update` command.
- The Path resolver incorrectly handled invalid symlinks.

## v0.8.0 - 2018-06-05 [REVOKED]

Features:
- Install shard executables inside project bin folder on shard install.
  See #126.

Changes:
- Global cache for cloned Git repositories, aside crystal cache
  (e.g. `~/.cache/shards`). Customizable with `SHARDS_CACHE_PATH`.
- Clone bare Git repositories instead of creating mirrors (fetch should be
  faster, and less space required on disk).
- Man pages are now in the `man` folder.
- Allow loose shard versioning, accepting semver-like versions and alternatives
  such as calver.

Fixes:
- Compatibility with Crystal 0.25.

## v0.7.2 - 2017-11-16

Features:
- Version command to print-out the project's version, see #147

Fixes:
- Don't consider a Git refs to be a version number, see #169
- Use installed spec for executing scripts, see #143
- Don't expect `shard.lock` when `shard.yml` has no dependencies, see #145
- Compatibility with Crystal 0.24.0 (unreleased)
- Harmonize error messages
- Correct shard.yml parse error line:column reporting

## v0.7.1 - 2016-11-24

Fixes:
- correctly updates or keeps dependencies, see #107, #141
- upgrades minitest dependency so test do run

## v0.7.0 - 2016-11-18

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

## v0.6.4 - 2016-11-18

Fixes:
- Compatibility with Crystal 0.19.0

## v0.6.3 - 2016-05-05

Fixes:
- Compatibility with Crystal > 0.15.0
- Relative paths for path dependencies, see #99

## v0.6.2 - 2016-03-07

Fixes:
- Don't crash when git binary is missing.

## v0.6.1 - 2016-02-16

Fixes:
- Compatibility with Crystal > 0.11.1

## v0.6.0 - 2016-01-23

Features:
- prune command to remove extraneous libs
- init command to create an initial shard.yml

Fixes:
- print details when postinstall script fails, see #84
- path resolver didn't verify the path actually existed, see #77
- recursion when shard name doesn't match dependency name, see #72

## v0.5.4 - 2015-12-23

Fixes:
- Compatibility with Crystal > 0.9.1

## v0.5.3 - 2015-10-23

Fixes:
- Git resolver didn't install the locked commit when using branch, tag or
  commit or just failed to install the dependency, see #65 and #67

## v0.5.2 - 2015-10-02

Fixes:
- compilation on Crystal 0.9.0

## v0.5.1 - 2015-10-02

Fixes:
- always generate a `shard.yml` when installing legacy dependencies, see #60
- only create `libs` and `.shards` folders when required, see #61

## v0.5.0 - 2015-09-28

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

## v0.4.0 - 2015-09-14

Features:
- lock resolved versions for indempotent installs across computers, see #27
- `--production` parameter to skip development dependencies
- postintall hook to run a command after installing a dependency, see #19

Breaking Changes:
- dropped support for custom dependency groups (but kept `development_dependencies`), see #27

Fixes:
- compatibility with Crystal 0.7.7

## v0.3.1 - 2015-08-16

Fixes:
- don't install dependencies from optional groups recursively
- manager didn't install path dependencies anymore

## v0.3.0 - 2015-08-03

Features:
- optional groups of dependencies, see #8
- generates default `shard.yml` from Git tags and `Projectfile` dependencies, see #6

Fixes:
- clone repository again when Git remote origin changes, see #4

## v0.2.0 - 2015-06-03

Fixes:
- correctly accesses git versioned `shard.yml` files;
- correctly links/extracts the `src` folder as the `libs/<name>` folder for both
  Git and path resolvers.

## v0.1.0 - 2015-05-23

Initial release.
