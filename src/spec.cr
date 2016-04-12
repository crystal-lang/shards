require "colorize"
require "yaml"
require "./config"
require "./dependency"
require "./errors"

module Shards
  class Spec
    class Author
      property name : String
      property email : String?

      def self.new(pull : YAML::PullParser)
        new(pull.read_scalar)
      end

      def initialize(name)
        if name =~ /\A\s*(.+?)\s*<(\s*.+?\s*)>/
          @name, @email = $1, $2
        else
          @name = name
        end
      end
    end

    def self.from_file(path, validate = false)
      path = File.join(path, SPEC_FILENAME) if File.directory?(path)
      raise Error.new("Missing #{ File.basename(path) }") unless File.exists?(path)
      from_yaml(File.read(path), path, validate)
    end

    def self.from_yaml(input, filename = SPEC_FILENAME, validate = false)
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

    getter! name : String?
    getter! version : String?
    getter description : String?
    getter license : String?

    # :nodoc:
    def initialize(pull : YAML::PullParser, validate = false)
      read_mapping(pull) do
        case key = pull.read_scalar
        when "name"
          @name = pull.read_scalar
        when "version"
          @version = pull.read_scalar
        when "description"
          @description = pull.read_scalar
        when "license"
          @license = pull.read_scalar
        when "authors"
          read_sequence(pull) do
            authors << Author.new(pull.read_scalar)
          end
        when "dependencies"
          read_mapping(pull) do
            dependency = Dependency.new(pull.read_scalar)
            read_mapping(pull) { dependency[pull.read_scalar] = pull.read_scalar }
            dependencies << dependency
          end
        when "development_dependencies"
          read_mapping(pull) do
            dependency = Dependency.new(pull.read_scalar)
            read_mapping(pull) { dependency[pull.read_scalar] = pull.read_scalar }
            development_dependencies << dependency
          end
        when "scripts"
          read_mapping(pull) do
            scripts[pull.read_scalar] = pull.read_scalar
          end
        else
          if validate
            raise YAML::ParseException.new("unknown attribute: #{ key }", pull.line_number, pull.column_number)
          else
            pull.skip
          end
        end
      end

      {% for attr in %w(name version) %}
        unless @{{ attr.id }}
          raise YAML::ParseException.new(
            "missing required attribute: {{ attr.id }}",
            pull.line_number,
            pull.column_number
          )
        end
      {% end %}
    end

    def name=(@name : String)
    end

    def version=(@version : String)
    end

    def authors
      @authors ||= [] of Author
    end

    def dependencies
      @dependencies ||= [] of Dependency
    end

    def development_dependencies
      @development_dependencies ||= [] of Dependency
    end

    def scripts
      @scripts ||= {} of String => String
    end

    def license_url
      if license = @license
        if license =~ %r(https?://)
          license
        else
          "http://opensource.org/licenses/#{ license }"
        end
      end
    end

    private def read_sequence(pull)
      pull.read_sequence_start
      until pull.kind == YAML::EventKind::SEQUENCE_END
        yield
      end
      pull.read_next
      nil
    end

    private def read_mapping(pull)
      pull.read_mapping_start
      until pull.kind == YAML::EventKind::MAPPING_END
        yield
      end
      pull.read_next
      nil
    end
  end
end
