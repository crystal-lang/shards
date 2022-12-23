# CHANGELOG

## v0.17.2 - 2022-12-26

- Improve error message when symlink failed on Windows ([#565](https://github.com/crystal-lang/shards/pull/565), thanks @straight-shoota)
- Inherit the standard input descriptor ([#561](https://github.com/crystal-lang/shards/pull/561), thanks @hovsater)

## v0.17.1 - 2022-09-30

- Fix: Don't raise an exception if install_path doesn't exist ([#557](https://github.com/crystal-lang/shards/pull/557), thanks @mjoerussell)
- Fix Fossil resolver when multiple dependencies are coming from the same website ([#558](https://github.com/crystal-lang/shards/pull/558), thanks @MistressRemilia)
- Adjust parameter name for `Resolver#install_sources` ([#559](https://github.com/crystal-lang/shards/pull/559), thanks @straight-shoota)

## v0.17.0 - 2022-03-24

- Add `make build` recipe ([#533](https://github.com/crystal-lang/shards/pull/533), thanks @straight-shoota)
- Fix unexpected token compiler error match ([#532](https://github.com/crystal-lang/shards/pull/532), thanks @straight-shoota)
- Honour `CRYSTAL` env var ([#534](https://github.com/crystal-lang/shards/pull/534), thanks @straight-shoota)
- No longer depend of external git user config ([#536](https://github.com/crystal-lang/shards/pull/536), thanks @luislavena)
- [CI] Update circleci xcode 13.2.1 ([#537](https://github.com/crystal-lang/shards/pull/537), thanks @straight-shoota)
- Output `STDERR` from the building process ([#540](https://github.com/crystal-lang/shards/pull/540), thanks @beta-ziliani)
- Fix grammar problems ([#543](https://github.com/crystal-lang/shards/pull/543), thanks @dinko-pehar)
- Add fossil resolver ([#530](https://github.com/crystal-lang/shards/pull/530), thanks @MistressRemilia)
- Add expanded local path to `shard.yml` error message in `PathResolver` ([#541](https://github.com/crystal-lang/shards/pull/541), thanks @straight-shoota)
- Avoid user defined git template in resolver ([#528](https://github.com/crystal-lang/shards/pull/528), thanks @lzap)
- Add run command ([#546](https://github.com/crystal-lang/shards/pull/546), thanks @luislavena)
- Re-enabled `~` support in path resolver ([#538](https://github.com/crystal-lang/shards/pull/538), thanks @masukomi)
- Add `--jobs` flag (parallel git fetch) ([#539](https://github.com/crystal-lang/shards/pull/539), thanks @m-o-e)

## v0.16.0 - 2021-10-06

Fixes:
- Fix error message for invalid shard.yml ([#516](https://github.com/crystal-lang/shards/pull/516), thanks @straight-shoota)
- [Makefile] Fix shard.lock recipe ([#515](https://github.com/crystal-lang/shards/pull/515), thanks @straight-shoota)
- Fix pass no-color and verbose flags to crystal build ([#517](https://github.com/crystal-lang/shards/pull/517), thanks @straight-shoota)

Features:
- Resolver for Mercurial repositories ([#458](https://github.com/crystal-lang/shards/pull/458), thanks @f-fr)
- Update manpages with mercurial information ([#526](https://github.com/crystal-lang/shards/pull/526), thanks @straight-shoota)
- Add `!=` operator for version resolve ([#520](https://github.com/crystal-lang/shards/pull/520), thanks @syeopite)
- Compress manpages on install ([#524](https://github.com/crystal-lang/shards/pull/524), thanks @straight-shoota)

## v0.15.0 - 2021-06-29

Fixes:

- Let `shards build` error if no targets defined ([#490](https://github.com/crystal-lang/shards/pull/490), thanks @straight-shoota)
- Fix to allow empty `shard.override.yml` ([#495](https://github.com/crystal-lang/shards/pull/495), thanks @straight-shoota)
- Stop expecting master to be the default branch for git ([#503](https://github.com/crystal-lang/shards/pull/503), thanks @szabgab)

Features:
- Add documentation for `shard.override.yml` ([#494](https://github.com/crystal-lang/shards/pull/494), thanks @straight-shoota)
- Warn only crystal version ([#496](https://github.com/crystal-lang/shards/pull/496), thanks @beta-ziliani, @bcardiff)
- Don't default the Crystal version to `<1.0.0`, use only the lower bound ([#493](https://github.com/crystal-lang/shards/pull/493), thanks @oprypin)
- Add `--skip-executables` ([#506](https://github.com/crystal-lang/shards/pull/506), thanks @straight-shoota)

Others:

- Escape automatic ligatures in AsciiDoc ([#489](https://github.com/crystal-lang/shards/pull/489), thanks @elebow)
- Fix links in README ([#500](https://github.com/crystal-lang/shards/pull/500), [#483](https://github.com/crystal-lang/shards/pull/483), thanks @szabgab, @kimburgess)
- Correct list identation in shard.yml.adoc ([#492](https://github.com/crystal-lang/shards/pull/492/files), thanks @elebow)
- Add getting started section to README ([#513](https://github.com/crystal-lang/shards/pull/513), thanks @straight-shoota)

## v0.14.1 - 2021-03-10

Fixes:

- Fix broken `SOURCE_DATE_EPOCH` in `docs.mk`. ([#479](https://github.com/crystal-lang/shards/pull/479), thanks @straight-shoota)

## v0.14.0 - 2021-02-23

Fixes:

- Improve error message when locked version is missing in source. ([#466](https://github.com/crystal-lang/shards/pull/466), thanks @straight-shoota)
- Fix touch install_path to not accidentally create file. ([#478](https://github.com/crystal-lang/shards/pull/478), thanks @straight-shoota)

Features:

- Add `--frozen` and `--without-development` CLI flags. ([#473](https://github.com/crystal-lang/shards/pull/473), thanks @straight-shoota)
- Add `--skip-postinstall` cli option to install and update. ([#475](https://github.com/crystal-lang/shards/pull/475), thanks @bcardiff)
- Treat github sources as case insensitive. ([#471](https://github.com/crystal-lang/shards/pull/471), thanks @stakach)

Others:

- Rewrite manpages in Asciidoc. ([#262](https://github.com/crystal-lang/shards/pull/262), thanks @straight-shoota)
- CI improvements and housekeeping. ([#454](https://github.com/crystal-lang/shards/pull/454), [#464](https://github.com/crystal-lang/shards/pull/464), thanks @j8r, @Sija)
- Bump crystal-molinillo to 0.2.0. ([#476](https://github.com/crystal-lang/shards/pull/476), thanks @bcardiff)

## v0.13.0 - 2021-01-21

Fixes:

- Fix outdated command for dependencies with no releases. ([#455](https://github.com/crystal-lang/shards/pull/455), thanks @straight-shoota)
- Fix outdated command with non-release installed. ([#456](https://github.com/crystal-lang/shards/pull/456), thanks @straight-shoota)
- Write lockfile even when there are no dependencies. ([#453](https://github.com/crystal-lang/shards/pull/453), thanks @straight-shoota)
- Touch install_path and lockfile to express dependency. ([#444](https://github.com/crystal-lang/shards/pull/444), thanks @straight-shoota)
- Improve git reliability by retrying on failures. ([#450](https://github.com/crystal-lang/shards/pull/450), thanks @fudanchii)
- Allow empty scalar for mappings/sequences. ([#451](https://github.com/crystal-lang/shards/pull/451), thanks @straight-shoota)
- Fix working directory in `capture`. ([#457](https://github.com/crystal-lang/shards/pull/457), thanks @f-fr)

Features:

- Add a fallback to alternate shards commands. ([#202](https://github.com/crystal-lang/shards/pull/202), thanks @Willamin)

Others:

- Use git's `checkout` feature directly to write out repo files. ([#435](https://github.com/crystal-lang/shards/pull/435), thanks @oprypin)
- Use `Process.quote` instead of the old platform-specific helper. ([#437](https://github.com/crystal-lang/shards/pull/437), thanks @oprypin)
- Don't use POSIX-specific shell constructs. ([#436](https://github.com/crystal-lang/shards/pull/436), thanks @oprypin)
- Don't use compile-time shell commands to determine build timestamp. ([#438](https://github.com/crystal-lang/shards/pull/438), thanks @oprypin)
- Expand Windows support + fix all specs. ([#447](https://github.com/crystal-lang/shards/pull/447), thanks @oprypin)
- Add continuous testing (including Windows) using GitHub Actions. ([#448](https://github.com/crystal-lang/shards/pull/448), thanks @oprypin)
- Cleanup unused code. ([#460](https://github.com/crystal-lang/shards/pull/460), thanks @f-fr)
- Fix outdated content in the `README.md` and `SPEC.md`. ([#434](https://github.com/crystal-lang/shards/pull/434), [#461](https://github.com/crystal-lang/shards/pull/461), [#462](https://github.com/crystal-lang/shards/pull/462), thanks @kojix2, @straight-shoota, @KimBurgess)

## v0.12.0 - 2020-08-05

Fixes:

- Disable interactive credential prompt for git resolver. ([#411](https://github.com/crystal-lang/shards/pull/411), thanks @straight-shoota)
- Display dependency name on parsing errors of `shard.yml`. ([#408](https://github.com/crystal-lang/shards/pull/408), thanks @straight-shoota)
- Handle ambiguous dependencies and update `shard.lock` if source of dependency change. ([#419](https://github.com/crystal-lang/shards/pull/419), [#429](https://github.com/crystal-lang/shards/pull/429), thanks @bcardiff)
- Reinstall when resolver changes. ([#425](https://github.com/crystal-lang/shards/pull/425), thanks @waj)

Features:

- Shards overrides. ([#422](https://github.com/crystal-lang/shards/pull/422), [#429](https://github.com/crystal-lang/shards/pull/429), thanks @bcardiff)
- Add `--ignore-crystal-version` related suggestion and warnings to guide user. ([#418](https://github.com/crystal-lang/shards/pull/418), thanks @bcardiff)
- Allow shards to read `SHARDS_OPTS` for addition command options. ([#417](https://github.com/crystal-lang/shards/pull/417), [#420](https://github.com/crystal-lang/shards/pull/420), thanks @bcardiff)
- Add convenient makefile arguments for packaging. ([#414](https://github.com/crystal-lang/shards/pull/414), thanks @bcardiff)

Others:

- Bump required Crystal to 0.35. ([#424](https://github.com/crystal-lang/shards/pull/424), thanks @bcardiff)
- Refactor: Move install responsibilities from `Resolver` to `Package`. ([#426](https://github.com/crystal-lang/shards/pull/426), thanks @waj)
- Refactor: Use `Package` for locks and installed shards. ([#428](https://github.com/crystal-lang/shards/pull/428), thanks @waj)
- Spec: Add `stdout` and `stderr` to `FailedCommand` message. ([#410](https://github.com/crystal-lang/shards/pull/410), thanks @straight-shoota)
- Spec: Fix failure under 32-bit Linux. ([#416](https://github.com/crystal-lang/shards/pull/416), thanks @lugia-kun)
- Fix builds. ([#421](https://github.com/crystal-lang/shards/pull/421), [#423](https://github.com/crystal-lang/shards/pull/423), thanks @bcardiff)

## v0.11.1 - 2020-06-08

Fixes:

- Support `crystal: x.y` values (without patch). ([#404](https://github.com/crystal-lang/shards/pull/404), thanks @bcardiff)

## v0.11.0 - 2020-06-05

Features:

-  **(breaking-change)** Use `crystal:` property to filter candidates version. ([#395](https://github.com/crystal-lang/shards/pull/395), thanks @waj, @bcardiff)
- Introduce `shard.lock` 2.0 format, run `shards install` to migrate. ([#349](https://github.com/crystal-lang/shards/pull/349), [#400](https://github.com/crystal-lang/shards/pull/400), thanks @waj)
- Support intersection in requirements `version: >= 1.0.0, < 2.0`. ([#394](https://github.com/crystal-lang/shards/pull/394), thanks @waj)
- Install dependencies in reverse topological order. ([#369](https://github.com/crystal-lang/shards/pull/369), thanks @waj)
- Use less bright colors for output. ([#373](https://github.com/crystal-lang/shards/pull/373), thanks @waj)
- Add error on duplicate arguments in `shard.yml`. ([#387](https://github.com/crystal-lang/shards/pull/387), thanks @straight-shoota)
- Replace `.sha1` files with a single `.shards.info`. ([#349](https://github.com/crystal-lang/shards/pull/349), [#366](https://github.com/crystal-lang/shards/pull/366), [#368](https://github.com/crystal-lang/shards/pull/368), [#401](https://github.com/crystal-lang/shards/pull/401), thanks @waj)

Fixes:

- Improve `GitRef` dependencies and locks. ([#388](https://github.com/crystal-lang/shards/pull/388), [#389](https://github.com/crystal-lang/shards/pull/389), thanks @waj,  @straight-shoota)
- Fix crash when a shard version didn't contain a `shard.yml`. ([#362](https://github.com/crystal-lang/shards/pull/362), thanks @waj)
- Avoid `shard.lock` being overwritten when dependencies are up to date. ([#370](https://github.com/crystal-lang/shards/pull/370), thanks @waj)
- Detect version mismatches between `shard.yml` and git tags . ([#341](https://github.com/crystal-lang/shards/pull/341), thanks @RX14)

Others:

- Add compatibility with Crystal 0.35. Drop compatibility with < 0.34. ([#379](https://github.com/crystal-lang/shards/pull/379), [#391](https://github.com/crystal-lang/shards/pull/391), [#397](https://github.com/crystal-lang/shards/pull/397), thanks @waj, @bcardiff)
- Explicitly state build_options in help output. ([#364](https://github.com/crystal-lang/shards/pull/364), thanks @Darwinnn)
- Use YAML parser for `Dependency` and `Target`. ([#306](https://github.com/crystal-lang/shards/pull/306), thanks @straight-shoota)
- Add lib to Makefile. ([#344](https://github.com/crystal-lang/shards/pull/344), [#380](https://github.com/crystal-lang/shards/pull/380), thanks @straight-shoota, @waj)
- Allow Makefile envvars to be overwritten from a command line. ([#378](https://github.com/crystal-lang/shards/pull/378), thanks @anatol)
- Rework of dependency and requirements. ([#354](https://github.com/crystal-lang/shards/pull/354), [#358](https://github.com/crystal-lang/shards/pull/358), thanks @waj)
- Add spec to check when there is a version mismatch. ([#361](https://github.com/crystal-lang/shards/pull/361), thanks @waj)
- Make sure tags in specs aren't signed. ([#382](https://github.com/crystal-lang/shards/pull/382), thanks @repomaa)
- Code clean-up. ([#356](https://github.com/crystal-lang/shards/pull/356), [#375](https://github.com/crystal-lang/shards/pull/375), thanks @straight-shoota)

## v0.10.0 - 2020-04-01

Features:

- Use [crystal-molinillo](https://github.com/crystal-lang/crystal-molinillo) to resolve dependencies, drop the SAT solver. [#322](https://github.com/crystal-lang/shards/pull/322), [#329](https://github.com/crystal-lang/shards/pull/329), [#336](https://github.com/crystal-lang/shards/pull/336).
- Automatic unlock on install and update. [#337](https://github.com/crystal-lang/shards/pull/337)
- Show the shard's name when running scripts. [#326](https://github.com/crystal-lang/shards/pull/326)
- Support shard renames. [#327](https://github.com/crystal-lang/shards/pull/327)
- Add SPEC for repository, homepage, documentation properties. [#265](https://github.com/crystal-lang/shards/pull/265)

Fixes:

- Allow changes in the source protocol without triggering an actual change in the source. [#315](https://github.com/crystal-lang/shards/pull/315)
- Make shards reproducible via `SOURCE_DATE_EPOCH` environment variable. [#314](https://github.com/crystal-lang/shards/pull/314)
- Check non hidden files are not pruned. [#330](https://github.com/crystal-lang/shards/pull/330)
- Validation of changes in production mode for dependencies referenced by commit. [#340](https://github.com/crystal-lang/shards/pull/340)

Others:

- Upgrade to Crystal 0.34.0. [#296](https://github.com/crystal-lang/shards/pull/296), [#331](https://github.com/crystal-lang/shards/pull/331), [#335](https://github.com/crystal-lang/shards/pull/335)
- Replace [minitest](https://github.com/ysbaddaden/minitest.cr) in favor of std-lib spec. [#334](https://github.com/crystal-lang/shards/pull/334)
- CI improvements and housekeeping. [#333](https://github.com/crystal-lang/shards/pull/333), [#317](https://github.com/crystal-lang/shards/pull/317), [#323](https://github.com/crystal-lang/shards/pull/323), [#328](https://github.com/crystal-lang/shards/pull/328)

## v0.9.0 - 2019-06-13

Fixes:
- Allow resolving pre-release when installing git refs;
- Report all available versions (Git resolver);
- Don't prune everything in `lib` directory.

## v0.9.0.rc2 - 2019-05-07

Fixes:
- Exit with non-zero status on dependency resolve error;
- Install dependency at HEAD when no version tags are defined;
- Install executables using `shard.yml` at commit (not version).

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
