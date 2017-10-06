require "./ext/yaml"
require "./dependency"

module Shards
  module Lock
    def self.from_file(path)
      raise Error.new("Missing #{ File.basename(path) }") unless File.exists?(path)
      from_yaml(File.read(path))
    end

    def self.from_yaml(str)
      dependencies = [] of Dependency

      pull = YAML::PullParser.new(str)
      pull.read_stream do
        pull.read_document do
          pull.read_mapping do
            key, value = pull.read_scalar, pull.read_scalar

            unless key == "version" && value == "1.0"
              raise InvalidLock.new
            end

            case key = pull.read_scalar
            when "shards"
              pull.each_in_mapping do
                dependencies << Dependency.new(pull)
              end
            else
              pull.raise "No such attribute #{key} in lock version 1.0"
            end
          end
        end
      end

      dependencies
    rescue ex : YAML::ParseException
      # raise ParseError.new(ex.message, str, LOCK_FILENAME, ex.line_number, ex.column_number)
      raise Error.new("Invalid #{ LOCK_FILENAME }. Please delete it and run install again.")
    ensure
      pull.close if pull
    end
  end
end
