require "yaml"
require "./dependency"

module Shards
  module Lock
    INVALID_FORMAT_MESSAGE = "Invalid #{ LOCK_FILENAME }. Please delete it and run install again."

    def self.from_file(path)
      from_yaml(File.read(path))
    end

    def self.from_yaml(str : String)
      data = YAML.load(str)
      raise Error.new(INVALID_FORMAT_MESSAGE) unless data.is_a?(Hash)

      case data["version"] as String
      when "1.0"
        dependencies = data["shards"]
        raise Error.new(INVALID_FORMAT_MESSAGE) unless dependencies.is_a?(Hash)

        dependencies.map do |name, config|
          raise Error.new(INVALID_FORMAT_MESSAGE) unless config.is_a?(Hash)
          Dependency.new(name.to_s, config)
        end
      else
        raise InvalidLock.new # unknown lock version
      end
    end
  end
end
