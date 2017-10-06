require "colorize"
require "./ext/yaml"
require "./config"
require "./dependency"
require "./errors"
require "./target"

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

    class Library
      property soname : String
      property version : String

      def self.new(pull : YAML::PullParser)
        name = pull.read_scalar

        line, column = pull.location
        version = pull.read_scalar.strip if pull.kind.scalar?

        if !version || version.try(&.empty?)
          pull.raise "library version for #{name} can't be empty, use * for any version", line, column
        end

        new(name, version)
      end

      def initialize(@soname, @version)
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
    getter crystal : String?

    # :nodoc:
    def initialize(pull : YAML::PullParser, validate = false)
      pull.each_in_mapping do
        line, column = pull.location

        case key = pull.read_scalar
        when "name"
          @name = pull.read_scalar
        when "version"
          @version = pull.read_scalar
        when "description"
          @description = pull.read_scalar
        when "license"
          @license = pull.read_scalar
        when "crystal"
          @crystal = pull.read_scalar
        when "authors"
          pull.each_in_sequence do
            authors << Author.new(pull.read_scalar)
          end
        when "dependencies"
          pull.each_in_mapping do
            dependencies << Dependency.new(pull)
          end
        when "development_dependencies"
          pull.each_in_mapping do
            development_dependencies << Dependency.new(pull)
          end
        when "targets"
          pull.each_in_mapping do
            targets << Target.new(pull)
          end
        when "libraries"
          pull.each_in_mapping do
            libraries << Library.new(pull)
          end
        when "scripts"
          pull.each_in_mapping do
            scripts[pull.read_scalar] = pull.read_scalar
          end
        else
          if validate
            pull.raise "unknown attribute: #{key}", line, column
          else
            pull.skip
          end
        end
      end

      {% for attr in %w(name version) %}
        unless @{{ attr.id }}
          pull.raise "missing required attribute: {{ attr.id }}"
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

    def targets
      @targets ||= [] of Target
    end

    def libraries
      @libraries ||= [] of Library
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
  end
end
