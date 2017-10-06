require "../spec"
require "../dependency"
require "../errors"
require "../script"
require "../file_utils"

module Shards
  abstract class Resolver
    PROJECTFILE_GITHUB_RE = /github\s+"(.+?\/(.+?))"(.*)/
    PROJECTFILE_GITHUB_BRANCH_RE = /"(.+?)"/

    getter dependency : Dependency

    def initialize(@dependency, @update_cache = true)
    end

    def spec(version = nil)
      Spec.from_yaml(read_spec(version))
    end

    def installed_spec
      return unless installed?

      path = File.join(install_path, SPEC_FILENAME)
      return Spec.from_file(path) if File.exists?(path)

      # TODO: raise instead of generating fake spec once shards is widely adopted
      Spec.from_yaml("name: #{dependency.name}\nversion: #{DEFAULT_VERSION}\n")
    end

    def installed?
      File.exists?(install_path)
    end

    abstract def read_spec(version = nil)
    abstract def available_versions
    abstract def install(version = nil)
    abstract def installed_commit_hash

    def run_script(name)
      if installed? && (command = installed_spec.try(&.scripts[name]?))
        Shards.logger.info "#{name.capitalize} #{command}"
        Script.run(install_path, command)
      end
    end

    protected def install_path
      File.join(Shards.install_path, dependency.name)
    end

    protected def cleanup_install_directory
      FileUtils.rm_rf(install_path)
    end

    protected def parse_legacy_projectfile_to_yaml(contents)
      dependencies = parse_dependencies_from_projectfile(contents)
        .map do |d|
          if d.has_key?("branch")
            "  #{d["name"]}:\n    github: #{d["github"]}\n    branch: #{d["branch"]}"
          else
            "  #{d["name"]}:\n    github: #{d["github"]}"
          end
        end

      if dependencies.any?
        "dependencies:\n#{dependencies.join("\n")}"
      end
    end

    protected def parse_dependencies_from_projectfile(contents)
      dependencies = Array(Hash(String, String)).new

      contents.scan(PROJECTFILE_GITHUB_RE) do |m|
        dependency = { "name" => m[2], "github" => m[1] }
        if m[3]? && (mm = m[3].match(PROJECTFILE_GITHUB_BRANCH_RE))
          dependency["branch"] = mm[1]
        end
        dependencies << dependency
      end

      dependencies
    end
  end

  @@resolver_classes = {} of String => Resolver.class
  @@resolvers = {} of String => Resolver

  def self.register_resolver(resolver)
    @@resolver_classes[resolver.key] = resolver
  end

  def self.find_resolver(dependency, update_cache = true)
    @@resolvers[dependency.name] ||= begin
      klass = get_resolver_class(dependency.keys)
      raise Error.new("Failed can't resolve dependency #{dependency.name} (unsupported resolver)") unless klass
      klass.new(dependency, update_cache: update_cache)
    end
  end

  private def self.get_resolver_class(names)
    names.each do |name|
      if resolver = @@resolver_classes[name.to_s]?
        return resolver
      end
    end

    nil
  end
end
