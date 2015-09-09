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

license: MIT
```


## Specification

Both libraries and applications will benefit from `shard.yml`.

The metadata for libraries are expected to have more information (eg: list of
authors, description, license) than applications that may only have a name and
dependencies.

### shard.yml

- It must be a valid YAML file.
- It must be UTF-8 encoded.
- It should be intended with 2 spaces.
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

Example: `0.0.1`, `1.2.3` or `2.0.0-rc1`.

While Shards doesn't enforce it, following a rational versioning scheme like
[Semantic Versioning](http://semver.org/) is highly recommended to avoid
frustrating the developers that use your library.

### authors

A list of authors, along with their contact email (Array or String).

- It must have an author name.
- It may have an email address between lower than (`<`) and greater than (`>`) chars.

Example:

```yaml
authors:
  - Ary
  - Julien Portalier <julien@example.org>
```

### description

A single line description of the library (String).

### license

An [OSI license](http://opensource.org/) or an URL to a license file (String,
recommended).

### dependencies

A list of required dependencies (Hash).

Each dependency begins with the name of the dependency as a key (String) then
a list of attributes (Hash) which depend on the resolver to use to download the
dependency.

Example:
```yaml
dependencies:
  minitest:
    github: ysbaddaden/minitest.cr
    version: 0.1.0
```


#### version

A version requirement (String).

- It must be a version number.
- It may be prefixed by an operator: `<`, `<=`, `>`, `>=`, `~>`.
- If prefixed by an operator, it may be only a fragment of the version number.

Examples: `1.0.0`, `> 1.0` or `~> 1.0.0`.

#### path

A local path (String).

The library will be linked from the local path. The `version` attribute
isn't required but will be used if present.

#### git

A Git repository URL (String).

The Git repository will be cloned, the list of versions (and associated
`shard.yml`) will be extracted from Git tags (eg: `v1.2.3`).

One of the other attributes (`version`, `tag`, `branch` or `commit`) is
required. When missing, Shards will install the HEAD refs.

Example: `git: git://git.example.org/crystal-library.git`

#### github

A GitHub repository (String).

The value is the `user/repository` sheme. Extends the `git` resolver, and acts
exactly like it. One of the other attributes (`version`, `tag`, `branch` o
r `commit`) is required. When missing Shards will install the HEAD refs.

Example: `github: ysbaddaden/minitest.cr`

#### bitbucket

A Bitbucket repository (String).

The value is the `user/repository` sheme. Extends the `git` resolver, and acts
exactly like it. One of the other attributes (`version`, `tag`, `branch` o
r `commit`) is required. When missing Shards will install the HEAD refs.

Example: `bitbucket: tom/library`

#### commit

Install a Git dependency at the specified commit (String).

#### tag

Install a Git dependency at the specified tag (String).

#### branch

Install a Git dependency at the specified branch (String).

#### Grouped Dependencies

Dependencies may be grouped. Those dependencies are installed in order to work
on the project or library itself. When the library is installed as a dependency
for another project or library, grouped dependencies will never be installed.

Grouped dependencies follow the same scheme than dependencies, but prefixed with
the group name followed by `_dependencies`.

Example: `development_dependencies`.
