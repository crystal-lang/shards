require "file_utils"
require "../spec"
require "../dependency"
require "../errors"
require "../script"

module Shards
  abstract class Resolver
    getter name : String
    getter source : String

    def initialize(@name : String, @source : String)
    end

    def self.build(key : String, name : String, source : String)
      self.new(name, source)
    end

    def ==(other : Resolver)
      return true if super
      return false unless self.class == other.class
      name == other.name && source == other.source
    end

    def installed_spec
      return unless installed?

      path = File.join(install_path, SPEC_FILENAME)
      unless File.exists?(path)
        raise Error.new("Missing #{SPEC_FILENAME.inspect} for #{name.inspect}")
      end

      spec = Spec.from_file(path)
      spec.version = Version.new(File.read(version_path)) if File.exists?(version_path)
      spec
    end

    def installed?
      File.exists?(install_path)
    end

    def versions_for(req : Requirement) : Array(Version)
      case req
      when Version then [req]
      when Ref
        versions_for_ref(req)
      when VersionReq
        Versions.resolve(available_releases, req)
      when Any
        releases = available_releases
        if releases.empty?
          versions_for_ref(nil)
        else
          releases
        end
      else
        raise Error.new("Unexpected requirement type: #{req}")
      end
    end

    private def versions_for_ref(ref : Ref?) : Array(Version)
      if version = latest_version_for_ref(ref)
        [version]
      else
        [] of Version
      end
    end

    abstract def available_releases : Array(Version)

    def latest_version_for_ref(ref : Ref?) : Version?
      raise "Unsupported ref type for this resolver: #{ref}"
    end

    def matches_ref?(ref : Ref, version : Version)
      false
    end

    def spec(version : Version) : Spec
      spec = Spec.from_yaml(read_spec(version))
      spec.resolver = self
      spec.version = version
      spec
    end

    abstract def read_spec(version : Version)
    abstract def install_sources(version : Version)
    abstract def report_version(version : Version) : String

    def install(version : Version)
      cleanup_install_directory

      install_sources(version)
      File.write(version_path, version.value)
    end

    def version_path
      @version_path ||= File.join(Shards.install_path, "#{name}.version")
    end

    def run_script(name)
      if installed? && (command = installed_spec.try(&.scripts[name]?))
        Log.info { "#{name.capitalize} of #{self.name}: #{command}" }
        Script.run(install_path, command, name, self.name)
      end
    end

    def install_path
      File.join(Shards.install_path, name)
    end

    protected def cleanup_install_directory
      Log.debug { "rm -rf '#{Helpers::Path.escape(install_path)}'" }
      FileUtils.rm_rf(install_path)
    end

    def parse_requirement(params : Hash(String, String)) : Requirement
      if version = params["version"]?
        VersionReq.new version
      else
        Any
      end
    end

    private RESOLVER_CLASSES = {} of String => Resolver.class
    private RESOLVER_CACHE   = {} of String => Resolver

    def self.register_resolver(key, resolver)
      RESOLVER_CLASSES[key] = resolver
    end

    def self.clear_resolver_cache
      RESOLVER_CACHE.clear
    end

    def self.find_class(key : String) : Resolver.class | Nil
      RESOLVER_CLASSES[key]?
    end

    def self.find_resolver(key : String, name : String, source : String)
      resolver_class =
        if self == Resolver
          RESOLVER_CLASSES[key]? ||
            raise Error.new("Failed can't resolve dependency #{name} (unsupported resolver)")
        else
          self
        end

      RESOLVER_CACHE[name] ||= begin
        resolver_class.build(key, name, source)
      end
    end
  end
end
