require "file_utils"

module Shards
  class Package
    getter name : String
    getter resolver : Resolver
    getter version : Version
    @spec : Spec?

    def initialize(@name, @resolver, @version)
    end

    def report_version
      resolver.report_version(version)
    end

    def spec
      @spec ||= resolver.spec(version)
    end

    def installed?
      if spec = resolver.installed_spec
        spec.version == version
      else
        false
      end
    end

    def install
      # install the shard:
      resolver.install(version)

      # link the project's lib path as the shard's lib path, so the dependency
      # can access transitive dependencies:
      unless resolver.is_a?(PathResolver)
        lib_path = File.join(resolver.install_path, "lib")
        Log.debug { "Link #{Shards.install_path} to #{lib_path}" }
        File.symlink("../../lib", lib_path)
      end
    end

    def postinstall
      resolver.run_script("postinstall")
    rescue ex : Script::Error
      resolver.cleanup_install_directory
      raise ex
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

        {% if compare_versions(Crystal::VERSION, "0.34.0-0") > 0 %}
          begin
            File.link(source, destination)
          rescue File::Error
            FileUtils.cp(source, destination)
          end
        {% else %}
          begin
            File.link(source, destination)
          rescue ex : Errno
            if {Errno::EPERM, Errno::EXDEV}.includes?(ex.errno)
              FileUtils.cp(source, destination)
            else
              raise ex
            end
          end
        {% end %}
      end
    end
  end
end
