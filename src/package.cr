require "file_utils"
require "./resolvers/*"

module Shards
  class Package
    getter name : String
    getter resolver : Resolver
    getter version : String
    getter commit : String?
    @spec : Spec?

    def initialize(@name, @resolver, @version, @commit)
    end

    def report_version
      if (resolver = self.resolver).is_a?(PathResolver)
        "#{version} at #{resolver.dependency_path}"
      else
        if commit
          "#{version} at #{commit}"
        else
          version
        end
      end
    end

    def spec
      @spec ||= resolver.spec(commit || version)
    end

    def installed?
      if spec = resolver.installed_spec
        (commit && resolver.installed_commit_hash == commit) || spec.version == version
      else
        false
      end
    end

    def install
      # install the shard:
      resolver.install(commit || version)

      # link the project's lib path as the shard's lib path, so the dependency
      # can access transitive dependencies:
      unless resolver.is_a?(PathResolver)
        lib_path = File.join(resolver.install_path, "lib")
        Shards.logger.debug { "Link #{Shards.install_path} to #{lib_path}" }
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
        Shards.logger.debug { "Install bin/#{name}" }
        source = File.join(resolver.install_path, "bin", name)
        destination = File.join(Shards.bin_path, name)

        if File.exists?(destination)
          next if File.same?(destination, source)
          File.delete(destination)
        end

        {% if compare_versions(Crystal::VERSION, "0.34.0-0") > 0 %}
          begin
            File.link(source, destination)
          rescue ex : File::Error
            if {Errno::EPERM, Errno::EXDEV}.includes?(ex.os_error)
              FileUtils.cp(source, destination)
            else
              raise ex
            end
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
