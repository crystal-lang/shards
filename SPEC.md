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

dependencies:
  openssl:
    github: datanoise/openssl.cr
    branch: master

development_dependencies:
  minitest:
    git: https://github.com/ysbaddaden/minitest.cr.git
    version: "~> 0.1.0"

scripts:
  postinstall: make ext

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

### authors

A list of authors, along with their contact email (Array of String).

- Each author must have a name.
- Each author may have an email address, within angle bracket (`<` and `>`) chars.

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

For further assistance in choosing an appropriate license, refer to the [website
curated by GitHub](http://choosealicense.com/) intended for exactly this.

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
- It may be `*` if any version will do.
- The version number may be prefixed by an operator: `<`, `<=`, `>`, `>=` or `~>`.

Examples: `1.2.3`, `>= 1.0.0` or `~> 2.0`.

#### path

A local path (String).

The library will be linked from the local path. The `version` attribute is not
required but will be used if present to validate the dependency.

#### git

A Git repository URL (String).

The URL may be of [any protocol](https://git-scm.com/docs/git-clone#_git_urls_a_id_urls_a)
supported by the git command line client, which includes `ssh`, `git`, and
`https`.

The Git repository will be cloned, the list of versions (and associated
`shard.yml`) will be extracted from Git tags (e.g., `v1.2.3`).

One of the other attributes (`version`, `tag`, `branch` or `commit`) is
required. When missing, Shards will install the HEAD refs.

Example: `git: git://git.example.org/crystal-library.git`

#### github

A [GitHub](https://github.com) repository (String).

The value is the `user/repository` scheme. Extends the `git` resolver, and acts
exactly like it. One of the other attributes (`version`, `tag`, `branch` or
`commit`) is required. When missing, Shards will install the HEAD refs.

Example: `github: ysbaddaden/minitest.cr`

#### bitbucket

A [Bitbucket](https://bitbucket.org) repository (String).

The value is the `user/repository` scheme. Extends the `git` resolver, and acts
exactly like it. One of the other attributes (`version`, `tag`, `branch` or
`commit`) is required. When missing, Shards will install the HEAD refs.

Example: `bitbucket: tom/library`

#### gitlab

A [GitLab](https://gitlab.com) repository (String).

The value is the `user/repository` scheme. Extends the `git` resolver, and acts
exactly like it. One of the other attributes (`version`, `tag`, `branch` or
`commit`) is required. When missing, Shards will install the HEAD refs.

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

### scripts

Shards may run scripts automatically after certain actions. The scripts
themselves are mere shell commands.

#### postinstall

The `postinstall` hook of a dependency will be run whenever that dependency is
installed or upgraded in a project that requires it. This may be used to compile
a C library, to build tools to help working on the project, or anything else.

The script will be run from the dependency's installation directory, for example
`libs/foo` for a Shard named `foo`.

```yaml
scripts:
  postinstall: cd src/libfoo && make
```
