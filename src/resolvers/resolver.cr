require "file_utils"
require "../spec"
require "../dependency"
require "../errors"
require "../script"

module Shards
  abstract class Resolver
    getter dependency : Dependency

    def initialize(@dependency)
    end

    def installed_spec
      return unless installed?

      path = File.join(install_path, SPEC_FILENAME)
      unless File.exists?(path)
        raise Error.new("Missing #{SPEC_FILENAME.inspect} for #{dependency.name.inspect}")
      end

      spec = Spec.from_file(path)
      spec.version = File.read(version_path) if File.exists?(version_path)
      spec
    end

    def installed?
      File.exists?(install_path)
    end

    def versions_for(dependency : Dependency) : Array(String)
      if ref = dependency.refs
        versions_for_ref(ref)
      else
        releases = available_releases
        if releases.empty?
          versions_for_ref(nil)
        elsif version_req = dependency.version?
          Versions.resolve(releases, version_req)
        else
          releases
        end
      end
    end

    private def versions_for_ref(ref : String?) : Array(String)
      if version = latest_version_for_ref(ref)
        [version]
      else
        [] of String
      end
    end

    abstract def available_releases : Array(String)
    abstract def latest_version_for_ref(ref : String?) : String?

    def matches_ref?(ref : Dependency, version : String)
      false
    end

    def spec(version : String) : Spec
      spec = Spec.from_yaml(read_spec(version))
      spec.resolver = self
      spec.version = version
      spec
    end

    abstract def read_spec(version : String)
    abstract def install_sources(version : String)

    def install(version : String)
      cleanup_install_directory

      install_sources(version)
      File.write(version_path, version)
    end

    def version_path
      @version_path ||= File.join(Shards.install_path, "#{dependency.name}.version")
    end

    def run_script(name)
      if installed? && (command = installed_spec.try(&.scripts[name]?))
        Log.info { "#{name.capitalize} of #{dependency.name}: #{command}" }
        Script.run(install_path, command, name, dependency.name)
      end
    end

    def install_path
      File.join(Shards.install_path, dependency.name)
    end

    protected def cleanup_install_directory
      Log.debug { "rm -rf '#{Helpers::Path.escape(install_path)}'" }
      FileUtils.rm_rf(install_path)
    end
  end

  @@resolver_classes = {} of String => Resolver.class
  @@resolvers = {} of String => Resolver

  def self.register_resolver(resolver)
    @@resolver_classes[resolver.key] = resolver
  end

  def self.find_resolver(dependency)
    @@resolvers[dependency.name] ||= begin
      if dependency.path
        PathResolver.new(dependency)
      elsif dependency.git
        GitResolver.new(dependency)
      else
        raise Error.new("Failed can't resolve dependency #{dependency.name} (missing resolver)")
      end
    end
  end
end
