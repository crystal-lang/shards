require "file_utils"
require "./helpers/files"

module Shards
  class Package
    getter name : String
    getter resolver : Resolver
    getter version : Version
    getter is_override : Bool
    @spec : Spec?

    def initialize(@name, @resolver, @version, @is_override = false)
    end

    def_equals @name, @resolver, @version

    def report_version
      resolver.report_version(version)
    end

    def spec
      @spec ||= begin
        if installed?
          read_installed_spec
        else
          resolver.spec(version)
        end
      end
    end

    private def read_installed_spec
      path = File.join(install_path, SPEC_FILENAME)
      unless File.exists?(path)
        return resolver.spec(version)
      end

      begin
        spec = Spec.from_file(path)
        spec.version = version
        spec
      rescue error : ParseError
        error.resolver = resolver
        raise error
      end
    end

    def installed?
      return false unless File.exists?(install_path)
      if installed = Shards.info.installed[name]?
        installed.resolver == resolver && installed.version == version
      else
        false
      end
    end

    def install_path
      File.join(Shards.install_path, name)
    end

    def install
      cleanup_install_directory

      # install the shard:
      resolver.install_sources(version, install_path)

      # link the project's lib path as the shard's lib path, so the dependency
      # can access transitive dependencies:
      unless resolver.is_a?(PathResolver)
        lib_path = File.join(install_path, Shards::INSTALL_DIR)
        Log.debug { "Link #{Shards.install_path} to #{lib_path}" }
        Dir.mkdir_p(File.dirname(lib_path))
        target = File.join(Path.new(Shards::INSTALL_DIR).parts.map { ".." })
        File.symlink(target, lib_path)
      end

      Shards.info.installed[name] = self
      Shards.info.save
    end

    protected def cleanup_install_directory
      Log.debug { "rm -rf #{Process.quote(install_path)}" }
      Shards::Helpers::Files.rm_rf(install_path)
    end

    def postinstall
      run_script("postinstall")
    rescue ex : Script::Error
      cleanup_install_directory
      raise ex
    end

    def run_script(name)
      if installed? && (command = spec.scripts[name]?)
        Log.info { "#{name.capitalize} of #{self.name}: #{command}" }
        Script.run(install_path, command, name, self.name)
      end
    end

    def install_executables
      return if !installed? || spec.executables.empty?

      Dir.mkdir_p(Shards.bin_path)

      spec.executables.each do |name|
        exe_name = name
        {% if flag?(:win32) %}
          exe_name += ".exe"
        {% end %}
        Log.debug { "Install bin/#{exe_name}" }
        source = File.join(install_path, "bin", exe_name)
        destination = File.join(Shards.bin_path, exe_name)

        if File.exists?(destination)
          next if File.same?(destination, source)
          File.delete(destination)
        end

        begin
          File.link(source, destination)
        rescue File::Error
          FileUtils.cp(source, destination)
        end
      end
    end

    def to_yaml(builder)
      Dependency.new(name, resolver, version).to_yaml(builder)
    end

    def to_s(io)
      io << name << " (" << report_version << ")"
    end
  end
end
