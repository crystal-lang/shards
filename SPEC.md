# `shard.yml` specification.

## Example

Here is an example `shard.yml` for a library named `shards` at version `1.2.3`
with some dependencies:

```yaml
name: shards
version: 1.2.3

authors:
  - Julien Portalier <julien@example.com>

description: |
  Dependency manager for the Crystal Language

crystal: 0.19.2

dependencies:
  openssl:
    github: datanoise/openssl.cr
    branch: master

development_dependencies:
  minitest:
    git: https://github.com/ysbaddaden/minitest.cr.git
    version: "~> 0.1.0"

libraries:
  libgit2: ~> 0.24

scripts:
  postinstall: make ext

targets:
  shards:
    main: src/shards.cr

license: MIT
```


## Specification

Both libraries and applications will benefit from `shard.yml`.

The metadata for libraries are expected to have more information (e.g., list of
authors, description, license) than applications that may only have a name and
dependencies.

### shard.yml

- It must be a valid YAML file.
- It must be UTF-8 encoded.
- It should be indented with 2 spaces.
- It should not use advanced YAML features, only simple hashes, arrays and strings.

### name

The name of library (String, required).

- It must be unique.
- It must be 50 characters or less.
- It should be lowercase (a-z).
- It should not contain `crystal`.
- It may contain digits (0-9) but not start with one.
- It may contain underscores or dashes but not start/end with one.
- It must not have consecutive underscores or dashes.

Examples: `minitest`, `mysql2`, `battery-horse`.

### version

The version number of the library (String, required).

- It should follow the [Semantic Versioning](http://semver.org/) format.
- It must contain digits.
- It may contain dots and dashes but not consecutive ones.

Examples: `0.0.1`, `1.2.3` or `2.0.0-rc1`.

While Shards doesn't enforce it, following a rational versioning scheme like
[Semantic Versioning](http://semver.org/) is highly recommended.

### authors

A list of authors, along with their contact email (Array of String).

- Each author must have a name.
- Each author may have an email address, within angle bracket (`<` and `>`)
  chars.

Example:

```yaml
authors:
  - Ary
  - Julien Portalier <julien@example.org>
```

### description

A single line description of the library (String).

### license

An [OSI license](http://opensource.org/) name or an URL to a license file
(String, recommended).

### crystal

The last known Crystal version that is capable to compile the Shard (String).

Purely informational, this may help developers to understand why a Shard is no
longer compatible, or help tools to choose a compatible version of Crystal to
work with the project (e.g., an automated documentation generator).

```yaml
crystal: 0.19.2
```

### dependencies

A list of required dependencies (Hash).

Each dependency begins with the name of the dependency as a key (String) then a
list of attributes (Hash) that depend on where the dependency is located (e.g.,
local path, Git repository).

Example:
```yaml
dependencies:
  minitest:
    github: ysbaddaden/minitest.cr
    version: 0.1.0
```

#### version

A version requirement (String).

- It may be a version number.
- It may be `"*"` if any version will do.
- The version number may be prefixed by an operator: `<`, `<=`, `>`, `>=` or `~>`.

Examples: `1.2.3`, `>= 1.0.0` or `~> 2.0`.

Most of the version operators, like `>= 1.0.0`, are self-explanatory, but
the `~>` operator has a special meaning, best shown by example:
- `~> 2.0.3` is identical to `>= 2.0.3 and < 2.1`;
- `~> 2.1` is identical to `>= 2.1 and < 3.0`.

#### path

A local path (String).

The library will be linked from the local path. The `version` attribute isn't
required but will be used if present to validate the dependency.

#### git

A Git repository URL (String).

The URL may be [any protocol](https://git-scm.com/docs/git-clone#_git_urls_a_id_urls_a)
supported by Git, which includes SSH, GIT and HTTPS.

The Git repository will be cloned, the list of versions (and associated
`shard.yml`) will be extracted from Git tags (e.g., `v1.2.3`).

One of the other attributes (`version`, `tag`, `branch` or `commit`) is
required. When missing, Shards will install the HEAD refs.

Example: `git: git://git.example.org/crystal-library.git`

#### github

A GitHub repository (String).

The value is the `user/repository` scheme. Extends the `git` resolver, and acts
exactly like it. One of the other attributes (`version`, `tag`, `branch` or
`commit`) is required. When missing, Shards will install the HEAD refs.

Example: `github: ysbaddaden/minitest.cr`

#### bitbucket

A Bitbucket repository (String).

The value is the `user/repository` sheme. Extends the `git` resolver, and acts
exactly like it. One of the other attributes (`version`, `tag`, `branch` o
r `commit`) is required. When missing Shards will install the HEAD refs.

Example: `bitbucket: tom/library`

#### gitlab

A GitLab repository (String).

The value is the `user/repository` scheme. Extends the `git` resolver, and acts
exactly like it. One of the other attributes (`version`, `tag`, `branch` or
`commit`) is required. When missing, Shards will install the HEAD refs.

Only matches dependencies hosted on `gitlab.com`. For personal GitLab
installations, you must use the generic `git` resolver.

Example: `gitlab: thelonlyghost/minitest.cr`

#### commit

Install a Git dependency at the specified commit (String).

#### tag

Install a Git dependency at the specified tag (String).

#### branch

Install a Git dependency at the specified branch (String).

### development_dependencies

Dependencies may be grouped together as a set of optional development
dependencies. Those will be installed for the main project or library itself.
When the library is installed as a dependency for another project the
development dependencies will never be installed.

Development dependencies follow the same scheme than dependencies.

Example:

```yaml
development_dependencies:
  minitest:
    github: ysbaddaden/minitest.cr
    version: ~> 0.1.3
```

### libraries

A list of shared libraries the shard tries to link to (Hash).

This field is purely informational. It serves as a canonical way to discover
non Crystal dependencies in shards, both for tools as well as humans.

A shard must only list libraries it directly links to, it must not include
libraries that are only referenced by dependencies. It must include all libraries
it directly links to, regardless of a dependency doing it too.

It should map from the soname without any extension, path or version,
for example `libsqlite3` for `/usr/lib/libsqlite3.so.0.8.6`, to a version
constraint.

The version constraint has the following format:

- It may be a version number.
- It may be `"*"` if any version will do.
- The version number may be prefixed by an operator: `<`, `<=`, `>`, `>=` or `~>`.

```yaml
libraries:
  libQt5Gui: "*"
  libQt5Help: ~> 5.7
  libQtBus: >= 4.8
```

### scripts

Shards may run scripts automatically after certain actions. The scripts
themselves are mere shell commands.

#### postinstall

The `postinstall` hook of a dependency will be run whenever that dependency is
installed or upgraded in a project that requires it. This may be used to compile
a C library, to build tools to help working on the project, or anything else.

The script will be run from the dependency's installation directory, for example
`lib/foo` for a Shard named `foo`.

```yaml
scripts:
  postinstall: cd src/libfoo && make
```

### targets

A list of targets to build (Hash).

Each target begins with the name of the target as a key (String), then a list of
attributes (Hash). The target name is the built binary name, created in the
`bin` folder of the project.

Example:

```yaml
targets:
  server:
    main: src/server/cli.cr
  worker:
    main: src/worker.cr
```

The above example will build `bin/server` from `src/server/cli.cr` and
`bin/worker` from `src/worker.cr`.

#### main

A path to the source file to compile (String).
