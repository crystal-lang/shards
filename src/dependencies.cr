require "yaml"

module Shards
  class Dependency < Hash(String, String)
    getter :name, :config

    def initialize(@name, config)
      super nil
      config.each { |k, v| self[k.to_s] = v.to_s }
      self["version"] ||= "*"
    end

    def resolver
      @resolver ||= begin
                      resolver = Shards.find_resolver(keys)
                      raise "can't resolve dependency #{name} (unknown resolver)" unless resolver
                      resolver.new(self)
                    end
    end

    def inspect(io)
      io << "#<" << self.class.name << " {\"" << name << "\" => "
      super
      io << "}>"
    end
  end

  class Shard
    getter :path

    def initialize(path)
      @path = if File.directory?(path)
                File.join(path, "shard.yml")
              else
                path
              end
    end

    def dependencies
      @dependencies ||= parse_shards
    end

    private def parse_shards
      shards = config["shards"]
      raise "expected hash" unless shards.is_a?(Hash)

      shards.map do |name, config|
        raise "expected hash" unless config.is_a?(Hash)
        Dependency.new(name.to_s, config)
      end
    end

    private def config
      @config ||= begin
                    config = YAML.load(File.read(path))
                    raise "expected hash" unless config.is_a?(Hash)
                    config
                  end
    end
  end

  def self.load_file(path = Dir.working_directory)
    Shard.new(path)
  end
end
