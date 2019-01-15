require "file_utils"
require "./resolvers/*"
require "./versions"

module Shards
  class Package
    getter requirements : Array(String)
    @resolver : Resolver?
    @available_versions : Array(String)?

    def initialize(@dependency : Dependency)
      @requirements = [] of String
    end

    def name
      @dependency.name
    end

    def version
      if refs = @dependency.refs
        refs
      elsif matching_versions.any?
        matching_versions.first
      else
        raise Conflict.new(self)
      end
    end

    def report_version
      if path = @dependency.path
        "#{spec.version} at #{path}"
      else
        version = self.version

        if version == spec.version
          version
        else
          "#{spec.version} at #{version}"
        end
      end
    end

    def matching_versions(prereleases = false)
      Versions.resolve(available_versions, requirements, prereleases)
    end

    def spec
      resolver.spec(version)
    end

    def matches?(commit)
      resolver = self.resolver

      if resolver.responds_to?(:matches?)
        resolver.matches?(commit)
      else
        raise LockConflict.new("wrong resolver")
      end
    end

    def installed?(version = self.version)
      if spec = resolver.installed_spec
        resolver.installed_commit_hash == version ||
          spec.version == version
      else
        false
      end
    end

    def install(version = nil)
      resolver.install(version || self.version)
      resolver.run_script("postinstall")
    rescue ex : Script::Error
      resolver.cleanup_install_directory
      raise ex
    end

    def install_executables
      return if !installed? || spec.executables.empty?

      Dir.mkdir_p(Shards.bin_path)

      spec.executables.each do |name|
        Shards.logger.debug "Install bin/#{name}"
        source = File.join(resolver.install_path, "bin", name)
        destination = File.join(Shards.bin_path, name)

        if File.exists?(destination)
          {% if File.class.has_method?(:same?) %}
            # Since Crystal 0.25.0
            next if File.same?(destination, source)
          {% else %}
            # Up to Crystal 0.24.2
            next if File.stat(destination).ino == File.stat(source).ino
          {% end %}
          File.delete(destination)
        end

        begin
          File.link(source, destination)
        rescue ex : Errno
          if {Errno::EPERM, Errno::EXDEV}.includes?(ex.errno)
            FileUtils.cp(source, destination)
          else
            raise ex
          end
        end
      end
    end

    def to_lock(io : IO)
      key = resolver.class.key
      io << "    " << key << ": " << @dependency[key] << '\n'

      if @dependency.refs || !(version =~ VERSION_REFERENCE)
        io << "    commit: " << resolver.installed_commit_hash.to_s << '\n'
      else
        io << "    version: " << version << '\n'
      end
    end

    def resolver
      @resolver ||= Shards.find_resolver(@dependency)
    end

    def available_versions(prereleases = true)
      versions = @available_versions ||= resolver.available_versions
      if prereleases
        versions
      else
        Versions.without_prereleases(versions)
      end
    end
  end

  class Set < Array(Package)
    def add(dependency)
      package = find { |package| package.name == dependency.name }

      unless package
        package = Package.new(dependency)
        self << package
      end

      unless dependency.name == package.spec.name
        raise Error.new("Error shard name (#{package.spec.name}) doesn't match dependency name (#{dependency.name})")
      end

      package.requirements << dependency.version
      package
    end
  end
end
