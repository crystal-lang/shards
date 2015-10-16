module Shards
  module CliHelper
    def before_setup
      super

      application_path.tap do |path|
        if File.exists?(path)
          run("rm -rf #{path}/*", capture: false)
          run("rm -rf #{path}/.shards", capture: false)
        else
          Dir.mkdir_p(path)
        end
      end
    end

    def with_shard(metadata, lock = nil)
      Dir.cd(application_path) do
        File.write "shard.yml", to_shard_yaml(metadata)
        File.write "shard.lock", to_lock_yaml(lock) if lock
        yield
      end
    end

    def to_shard_yaml(metadata)
      String.build do |yml|
        yml << "name: " << (metadata[:name]? || "test").inspect << "\n"
        yml << "version: " << (metadata[:version]? || "0.0.0").inspect << "\n"

        metadata.each do |key, value|
          if key.to_s.ends_with?("dependencies")
            yml << key << ":"

            if value.responds_to?(:each)
              yml << "\n"
              value.each do |name, version|
                yml << "  " << name << ":\n"
                yml << "    git: " << git_url(name).inspect << "\n"

                if version.is_a?(String)
                  yml << "    version: " << version.inspect << "\n"
                else
                  version.each do |k, v|
                    yml << "    " << k << ": " << v << "\n"
                  end
                end
              end
            else
              yml << value
            end
          end
        end
      end
    end

    def to_lock_yaml(lock)
      return unless lock

      String.build do |yml|
        yml << "version: 1.0\n"
        yml << "shards:\n"

        lock.each do |name, version|
          yml << "  " << name << ":\n"
          yml << "    git: " << git_url(name).inspect << "\n"
          yml << "    version: " << version.inspect << "\n"
        end
      end
    end

    def application_path
      @application_path ||= File.expand_path("../../tmp/integration", __DIR__).tap do |path|
        if File.exists?(path)
          run("rm -rf #{path}/*", capture: false)
          run("rm -rf #{path}/.shards", capture: false)
        else
          Dir.mkdir_p(path)
        end
      end
    end
  end
end

class Minitest::Test
  include Shards::CliHelper
end
