require "file_utils"
require "set"
require "./helpers"

module Shards
  class Package
    getter name : String
    getter resolver : Resolver
    getter version : Version
    getter is_override : Bool
    getter dependencies = [] of Package
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
      Log.with_context do
        Log.context.set package: name

        cleanup_install_directory

        # install the shard:
        resolver.install_sources(version, install_path)

        sync_dependency_links
      end

      Shards.info.installed[name] = self
      Shards.info.save
    end

    # Only maintain directories created by Shards. Existing lib directories and
    # legacy lib -> .. links may belong to the dependency or the user.
    def sync_dependency_links
      return if resolver.is_a?(PathResolver)

      lib_path = File.join(install_path, Shards::INSTALL_DIR)
      return if File.symlink?(lib_path)

      marker = File.join(lib_path, ".shards")
      unless File.file?(marker)
        return if File.exists?(lib_path) || dependencies.empty?
        Dir.mkdir_p(lib_path)
        File.touch(marker)
      end

      # Crystal resolves all requires against the current working directory's
      # lib, so direct dependencies alone are not enough.
      reachable = Set(Package).new
      pending = dependencies.dup
      until pending.empty?
        dependency = pending.pop
        next unless reachable.add?(dependency)
        pending.concat(dependency.dependencies)
      end
      names = reachable.map(&.name).to_set
      target_path = Path.new(Shards.install_path).relative_to(lib_path)

      # Remove obsolete generated links, leaving files and other link targets alone.
      Dir.each_child(lib_path) do |name|
        next if names.includes?(name)
        link = File.join(lib_path, name)
        if File.symlink?(link) && File.readlink(link) == target_path.join(name).to_s
          File.delete(link)
        end
      end

      Dir.cd(lib_path) do
        names.each do |name|
          next if File.exists?(name) || File.symlink?(name)
          target = target_path.join(name).to_s
          Log.debug { "Link #{target} to #{File.join(lib_path, name)}" }
          File.symlink(target, name)
        end
      end
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

      Log.with_context do
        Log.context.set package: name
        spec.executables.each do |name|
          exe_name = find_executable_file(Path[install_path], name)
          unless exe_name
            raise Shards::Error.new("Could not find executable #{name.inspect} for #{@name.inspect}")
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
