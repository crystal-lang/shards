---
name: shards-manifest
description: Specialized guidance for parsing, validating, and generating Shards manifest specifications (shard.yml), dependency overrides (shard.override.yml), lockfiles (shard.lock), and package installation metadata (.shards.info).
---

# Shards Manifest, Lockfile & Model Domain Guide

This skill provides comprehensive architectural and operational standards for working with the **Shards manifest subsystem**. It covers `shard.yml` specification models, `YAML::PullParser` stream idioms, `shard.override.yml` resolution, `shard.lock` v1.0 and v2.0 formats, and the `.shards.info` local package registry.

---

## Compatibility Matrix

| Feature / Model | Shards Legacy (< v0.10.0 / Lock v1.0) | Shards Modern (v0.20.0+ / Lock v2.0) |
| :--- | :--- | :--- |
| **Lockfile Format** | Format `1.0` (stored raw git refs/branches) | Format `2.0` (canonical explicit commit hashes & SemVer tags) |
| **Manifest Parsing** | In-memory hash mapping | Streaming event-based `YAML::PullParser` with duplicate key checks |
| **Target Manifest** | Single entrypoint assumption | Multiple `targets` with `name` and `main` entrypoint mapping |
| **Dependency Overrides** | Ad-hoc CLI path substitution | Formal `shard.override.yml` and `SHARDS_OVERRIDE` environment overrides |
| **Installed Metadata** | Legacy `.sha1` digest files | Structured `.shards.info` (YAML mapping of active packages) |
| **License Normalization** | Raw license string | Automatic SPDX license URI generation (`https://spdx.org/licenses/<license>`) |

---

## Core Mandates

1. **Streaming YAML PullParser Idiom**: Always parse manifest YAML using `YAML::PullParser` with `each_in_mapping` and `each_in_sequence`. Never parse untrusted manifest files into generic dynamic hash structures.
2. **Duplicate Key Prevention**: Every attribute parsed from a YAML mapping MUST invoke `check_duplicate` on nilable instance variables before reading. Lazy getters (e.g. `def dependencies; @dependencies ||= [] of Dependency; end`) ensure the field is `nil` prior to the first assignment.
3. **Mandatory Manifest Attributes**: Every valid `shard.yml` must contain `name` and `version`. Missing either attribute must raise a `YAML::ParseException` or `Shards::ParseError`.
4. **Cross-Platform Path Sanitization**: When resolving package installation directories (`Package#install_path`), canonicalize the path with `Path.expand`, normalize path separators (`\` $\rightarrow$ `/` on Windows), and verify that the target directory is strictly equal to or prefixed with `#{base_path}/`.
5. **Zero Unsafe Nil Assertions**: Never use `.not_nil!` when unwrapping optional manifest attributes (`description`, `license`, `authors`, `targets`). Use conditional type narrowing or `getter!` macros.

---

## Patterns from Source Code

### 1. Parsing `shard.yml` with `YAML::PullParser`

```crystal
require "yaml"

module Shards
  class Spec
    getter! name : String?
    getter! version : Version?
    getter! original_version : Version?
    getter description : String?
    getter license : String?
    getter crystal : String?
    getter? read_from_yaml : Bool = false

    @authors : Array(Author)?
    @dependencies : Array(Dependency)?
    @development_dependencies : Array(Dependency)?
    @targets : Array(Target)?
    @executables : Array(String)?
    @scripts : Hash(String, String)?

    def self.from_file(path : String, validate : Bool = false) : self
      path = File.join(path, SPEC_FILENAME) if File.directory?(path)
      raise Error.new("Missing #{File.basename(path)}") unless File.exists?(path)
      from_yaml(File.read(path), path, validate)
    end

    def self.from_yaml(input : String, filename = SPEC_FILENAME, validate = false) : self
      parser = YAML::PullParser.new(input)
      parser.read_stream do
        parser.read_document do
          new(parser, validate)
        end
      end
    rescue ex : YAML::ParseException
      raise ParseError.new(ex.message, input, filename, ex.line_number, ex.column_number)
    ensure
      parser.close if parser
    end

    def initialize(pull : YAML::PullParser, validate = false)
      pull.each_in_mapping do
        line, column = pull.location

        case key = pull.read_scalar
        when "name"
          check_duplicate(@name, "name", line, column)
          @name = pull.read_scalar
        when "version"
          check_duplicate(@version, "version", line, column)
          @original_version = @version = Version.new(pull.read_scalar)
        when "description"
          check_duplicate(@description, "description", line, column)
          @description = pull.read_scalar
        when "license"
          check_duplicate(@license, "license", line, column)
          @license = pull.read_scalar
        when "crystal"
          check_duplicate(@crystal, "crystal", line, column)
          @crystal = pull.read_scalar
        when "dependencies"
          check_duplicate(@dependencies, "dependencies", line, column)
          pull.read_empty_or do
            pull.each_in_mapping do
              dependencies << Dependency.from_yaml(pull)
            end
          end
        when "development_dependencies"
          check_duplicate(@development_dependencies, "development_dependencies", line, column)
          pull.read_empty_or do
            pull.each_in_mapping do
              development_dependencies << Dependency.from_yaml(pull)
            end
          end
        when "targets"
          check_duplicate(@targets, "targets", line, column)
          pull.read_empty_or do
            pull.each_in_mapping do
              targets << Target.new(pull)
            end
          end
        else
          if validate
            pull.raise "unknown attribute: #{key}", line, column
          else
            pull.skip
          end
        end
      end

      unless @name && @version
        pull.raise "missing required attribute: name or version"
      end
      @read_from_yaml = true
    end

    private def check_duplicate(argument, name, line, column)
      unless argument.nil?
        raise YAML::ParseException.new("duplicate attribute #{name.inspect}", line, column)
      end
    end

    def dependencies : Array(Dependency)
      @dependencies ||= [] of Dependency
    end

    def development_dependencies : Array(Dependency)
      @development_dependencies ||= [] of Dependency
    end

    def targets : Array(Target)
      @targets ||= [] of Target
    end

    def executables : Array(String)
      @executables ||= [] of String
    end

    def scripts : Hash(String, String)
      @scripts ||= {} of String => String
    end

    def mismatched_version? : Bool
      Versions.compare(version, original_version) != 0
    end
  end
end
```

### 2. Lockfile Generation (Version 2.0 Format)

```crystal
module Shards
  class Lock
    CURRENT_VERSION = "2.0"

    def self.write(packages : Array(Package), override_path : String?, io : IO) : Nil
      if packages.any?(&.is_override)
        io << "# NOTICE: This lockfile contains some overrides from #{override_path}\n"
      end
      io << "version: #{CURRENT_VERSION}\n"
      io << "shards:"

      if packages.empty?
        io << " {}\n"
      else
        io.puts
        packages.sort_by!(&.name).each do |package|
          key = package.resolver.class.key
          io << "  " << package.name << ":#{package.is_override ? " # Overridden" : nil}\n"
          io << "    " << key << ": " << package.resolver.source << '\n'
          io << "    version: " << package.version.value << '\n'
          io << '\n'
        end
      end
    end
  end
end
```

### 3. Installed State Management (`.shards.info`)

```crystal
class Shards::Info
  getter install_path : String
  getter installed = Hash(String, Package).new

  def initialize(@install_path = Shards.install_path)
    reload
  end

  def reload : Nil
    path = info_path
    if File.exists?(path)
      @installed = Lock.from_file(path).shards.index_by(&.name)
    else
      @installed.clear
    end
  end

  def save : Nil
    Dir.mkdir_p(@install_path)
    File.open(info_path, "w") do |file|
      YAML.build(file) do |yaml|
        yaml.mapping do
          yaml.scalar "version"
          yaml.scalar "1.0"
          yaml.scalar "shards"
          yaml.mapping do
            installed.each do |name, dep|
              dep.to_yaml(yaml)
            end
          end
        end
      end
    end
  end

  def info_path : String
    File.join(@install_path, ".shards.info")
  end
end
```

---

## Best Practices

### Cross-Platform Security & Sanitization
* **Path Traversal Containment**: Enforce strict canonicalization and Windows backslash normalization when calculating installation paths:
  ```crystal
  def install_path : String
    path = Path[Shards.install_path, name].expand
    base_path = Path[Shards.install_path].expand

    path_str = path.to_s
    base_path_str = base_path.to_s

    {% if flag?(:win32) %}
      path_str = path_str.tr('\\', '/')
      base_path_str = base_path_str.tr('\\', '/')
    {% end %}

    unless path_str == base_path_str || path_str.starts_with?("#{base_path_str}/")
      raise Shards::Error.new("Invalid package name: #{name.inspect} (path traversal detected)")
    end

    File.join(Shards.install_path, name)
  end
  ```
* **Executable Name Validation**: Ensure target and executable names do not contain relative path separators (`..`, `/`, `\`) or Windows drive colons (`:`).

### Memory & Parsing Efficiency
* Use `YAML::PullParser#read_empty_or` to cleanly handle empty dependency mappings (e.g. `dependencies: ~` or `dependencies:`) without allocating empty container objects.
* Use `Version` value objects instead of raw strings to avoid repeated regex validations during manifest inspection.

---

## When to Use

Use this skill whenever you are:
1. Parsing, generating, or modifying `shard.yml`, `shard.override.yml`, or `shard.lock`.
2. Inspecting installed packages via `.shards.info` or `Shards::Info`.
3. Validating manifest schemas, compilation targets (`Shards::Target`), or package metadata.
4. Implementing custom tooling or analyzers that read Crystal shard configurations.
