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

The metadata for libraries are expected to have more information (eg: list of
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
- Each author may have an email address, within lower than (`<`) and greater than (`>`) chars.

Example:

```yaml
authors:
  - Ary
  - Julien Portalier <julien@example.org>
```

### description

A single line description of the library (String).

### license

An [OSI license](http://opensource.org/) name or an URL to a license file (String,
recommended).

### dependencies

A list of required dependencies (Hash).

Each dependency begins with the name of the dependency as a key (String) then
a list of attributes (Hash) that depend on where the dependency is located
(eg: local path, Git repository).

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

The library will be linked from the local path. The `version` attribute
isn't required but will be used if present to validate the dependency.

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

### development_dependencies

Dependencies may be grouped together as a set of optional development
dependencies. Those will be installed for the main project or library
itself. When the library is installed as a dependency for another
project the development dependencies will never be installed.

Development dependencies follow the same scheme than dependencies.
Example:

```yaml
development_dependencies:
  minitest:
    github: ysbaddaden/minitest.cr
    version: ~> 0.1.3
```

### scripts

Shards may run scripts automatically after certain actions. Scripts are mere
shell commands, and can either download and/or compile a library for example.

#### postinstall

The `postinstall` option is for running a command after your project is installed as a dependency of another project. This command does not run when running `shards install` inside the project specifying the hook. Note that the directory the script is ran from is `libs/some_shard/` of the project installing your shard as a dependency. You can use this to compile additional extensions needed, such as C libs.

As an example, if `guardian` was a dependency of a project called blog, then running `shards install` in that project would execute the postinstall script right after the `guardian` dependency was installed. It would not run for that project itself.

```yaml
name: some_shard
version: 0.0.1

scripts:
  postinstall: ./configure && make install
```
