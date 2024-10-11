require "file_utils"
require "./helpers"

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
        install_lib_path
      end

      Shards.info.installed[name] = self
      Shards.info.save
    end

    private def install_lib_path
      lib_path = File.join(install_path, Shards::INSTALL_DIR)
      return if File.exists?(lib_path)

      Log.debug { "Link #{Shards.install_path} to #{lib_path}" }
      Dir.mkdir_p(File.dirname(lib_path))
      target = File.join(Path.new(Shards::INSTALL_DIR).parts.map { ".." })
      File.symlink(target, lib_path)
    end

    protected def cleanup_install_directory
      Log.debug { "rm -rf #{Process.quote(install_path)}" }
      Shards::Helpers.rm_rf(install_path)
    end

    def postinstall
      run_script("postinstall", Shards.skip_postinstall?)
    rescue ex : Script::Error
      cleanup_install_directory
      raise ex
    end

    def run_script(name, skip)
      if installed? && (command = spec.scripts[name]?)
        if !skip
          Log.info { "#{name.capitalize} of #{self.name}: #{command}" }
          Script.run(install_path, command, name, self.name)
        else
          Log.info { "#{name.capitalize} of #{self.name}: #{command} (skipped)" }
        end
      end
    end

    def install_executables
      return if !installed? || spec.executables.empty? || Shards.skip_executables?

      Dir.mkdir_p(Shards.bin_path)

      spec.executables.each do |name|
        exe_name = find_executable_file(Path[install_path], name)
        unless exe_name
          raise Shards::Error.new("Could not find executable #{name.inspect}")
        end
        Log.debug { "Install #{exe_name}" }
        source = File.join(install_path, exe_name)
        destination = File.join(Shards.bin_path, File.basename(exe_name))

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

    def find_executable_file(install_path, name)
      each_executable_path(name) do |path|
        return path if File.exists?(install_path.join(path))
      end
    end

    private def each_executable_path(name, &)
      exe = Shards::Helpers.exe(name)
      yield Path["bin", exe]
      yield Path["bin", name] unless name == exe
    end

    def to_yaml(builder)
      Dependency.new(name, resolver, version).to_yaml(builder)
    end

    def to_s(io)
      io << name << " (" << report_version << ")"
    end
  end
end
