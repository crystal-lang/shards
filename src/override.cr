require "colorize"
require "./ext/yaml"
require "./config"
require "./dependency"
require "./errors"
require "./target"

module Shards
  class Override
    def self.from_file(path, validate = false)
      path = File.join(path, OVERRIDE_FILENAME) if File.directory?(path)
      raise Error.new("Missing #{File.basename(path)}") unless File.exists?(path)
      from_yaml(File.read(path), path, validate)
    end

    def self.from_yaml(input, filename = OVERRIDE_FILENAME, validate = false)
      parser = YAML::PullParser.new(input)
      parser.read_stream do
        parser.read_document do
          new(parser, validate)
        end
      end
    rescue ex : YAML::ParseException
      raise ParseError.new(ex.message, input, filename, ex.line_number, ex.column_number)
    ensure
      parser.close if parser
    end

    def initialize(@resolver : Resolver? = nil)
      @read_from_yaml = false
    end

    property resolver : Resolver?
    getter? read_from_yaml : Bool

    # :nodoc:
    def initialize(pull : YAML::PullParser, validate = false)
      pull.each_in_mapping do
        line, column = pull.location

        case key = pull.read_scalar
        when "dependencies"
          check_duplicate(@dependencies, "dependencies", line, column)
          pull.each_in_mapping do
            dependencies << Dependency.from_yaml(pull, is_override: true)
          end
        else
          if validate
            pull.raise "unknown attribute: #{key}", line, column
          else
            pull.skip
          end
        end
      end

      @read_from_yaml = true
    end

    private def check_duplicate(argument, name, line, column)
      unless argument.nil?
        raise YAML::ParseException.new("duplicate attribute #{name.inspect}", line, column)
      end
    end

    def dependencies
      @dependencies ||= [] of Dependency
    end
  end
end
