require "file_utils"

module Shards
  class Package
    getter name : String
    getter resolver : Resolver
    getter version : Version
    getter is_override : Bool
    @spec : Spec?

    def initialize(@name, @resolver, @version, @is_override = false)
    end

    def report_version
      resolver.report_version(version)
    end

    def spec
      @spec ||= resolver.spec(version)
    end

    def installed?
      if installed = Shards.info.installed[name]?
        installed.resolver == resolver && installed.requirement == version
      else
        false
      end
    end

    def install_path
      File.join(Shards.install_path, name)
    end

    def install
      # install the shard:
      resolver.install(version)

      # link the project's lib path as the shard's lib path, so the dependency
      # can access transitive dependencies:
      unless resolver.is_a?(PathResolver)
        lib_path = File.join(resolver.install_path, Shards::INSTALL_DIR)
        Log.debug { "Link #{Shards.install_path} to #{lib_path}" }
        Dir.mkdir_p(File.dirname(lib_path))
        target = File.join(Path.new(Shards::INSTALL_DIR).parts.map { ".." })
        File.symlink(target, lib_path)
      end
    end

    def postinstall
      run_script("postinstall")
    rescue ex : Script::Error
      resolver.cleanup_install_directory
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
        Log.debug { "Install bin/#{name}" }
        source = File.join(resolver.install_path, "bin", name)
        destination = File.join(Shards.bin_path, name)

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
end
