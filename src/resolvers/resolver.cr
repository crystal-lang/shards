require "file_utils"
require "../spec"
require "../dependency"
require "../errors"
require "../script"

module Shards
  abstract class Resolver
    getter dependency : Dependency

    def initialize(@dependency, @update_cache = true); end

    def spec(version = nil)
      Spec.from_yaml(read_spec(version))
    end

    def installed_spec
      return unless installed?

      path = File.join(install_path, SPEC_FILENAME)
      return Spec.from_file(path) if File.exists?(path)

      raise Error.new("Missing #{shards_location.inspect} for #{dependency.name.inspect}")
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

    def install_path
      File.join(Shards.install_path, dependency.name)
    end

    protected def cleanup_install_directory
      Shards.logger.debug "rm -rf '#{Helpers::Path.escape(install_path)}'"
      FileUtils.rm_rf(install_path)
    end

    protected def shards_location
      if dependency.dep
        "#{dependency.dep}/#{SPEC_FILENAME}"
      else
        SPEC_FILENAME
      end
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
