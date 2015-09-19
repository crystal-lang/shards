require "yaml"
require "./dependency"
require "./errors"

module Shards
  class Spec
    getter :name, :version

    def self.from_file(path)
      path = File.join(path, SPEC_FILENAME) if File.directory?(path)
      raise Error.new("Missing #{ File.basename(path) }") unless File.exists?(path)
      from_yaml(File.read(path))
    end

    def self.from_yaml(data : String)
      config = YAML.load(data) as Hash
      spec = new(config)
    rescue TypeCastError
      if spec
        raise Error.new("Invalid #{ SPEC_FILENAME } for #{ spec.name }@#{ spec.version }.")
      else
        raise Error.new("Invalid #{ SPEC_FILENAME }.")
      end
    end

    def initialize(@config)
      @name = (config["name"] as String).strip
      @version = config["version"]?.to_s.strip
    end

    def authors
      to_authors(@config["authors"]?)
    end

    def dependencies
      to_dependencies(@config["dependencies"]?)
    end

    def development_dependencies
      to_dependencies(@config["development_dependencies"]?)
    end

    def scripts
      if scripts = @config["scripts"]?
        if scripts.is_a?(Hash)
          scripts
        end
      end
    end

    def script(name)
      if scripts = self.scripts
        scripts[name]? as String
      end
    end

    private def to_authors(ary)
      if ary.is_a?(Array)
        ary.map(&.to_s.strip)
      else
        [] of String
      end
    end

    private def to_dependencies(hsh)
      dependencies = [] of Dependency

      if hsh.is_a?(Hash)
        hsh.map do |name, h|
          config = {} of String => String
          (h as Hash).each { |k, v| config[k.to_s.strip] = v.to_s.strip }
          dependencies << Dependency.new(name.to_s.strip, config)
        end
      end

      dependencies
    end
  end
end
