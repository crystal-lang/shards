require "yaml"
require "./dependency"

module Shards
  module Lock
    def self.from_file(path)
      raise Error.new("Missing #{ File.basename(path) }") unless File.exists?(path)
      from_yaml(File.read(path))
    end

    def self.from_yaml(str : String)
      data = YAML.load(str) as Hash

      case data["version"] as String
      when "1.0"
        (data["shards"] as Hash).map do |name, config|
          Dependency.new(name.to_s, config as Hash)
        end
      else
        raise InvalidLock.new # unknown lock version
      end
    rescue TypeCastError | KeyError
      raise Error.new("Invalid #{ LOCK_FILENAME }. Please delete it and run install again.")
    end
  end
end
