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

    def to_s(io)
      io << name << " " << version
    end

    def self.from_file(path, validate = false)
      path = File.join(path, SPEC_FILENAME) if File.directory?(path)
      raise Error.new("Missing #{File.basename(path)}") unless File.exists?(path)
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

    def initialize(@name : String, @version : Version, @resolver : Resolver? = nil)
      @original_version = @version
      @read_from_yaml = false
    end

    getter! name : String?
    getter! version : Version?
    getter! original_version : Version?
    getter description : String?
    getter license : String?
    getter crystal : String?
    property resolver : Resolver?
    getter? read_from_yaml : Bool

    def mismatched_version?
      Versions.compare(version, original_version) != 0
    end

    # :nodoc:
    def initialize(pull : YAML::PullParser, validate = false)
      pull.each_in_mapping do
        line, column = pull.location

        case key = pull.read_scalar
        when "name"
          check_duplicate(@name, "name", line, column)
          @name = pull.read_scalar
        when "version"
          check_duplicate(@version, "version", line, column)
          @original_version = @version = Version.new(pull.read_scalar)
        when "description"
          check_duplicate(@description, "description", line, column)
          @description = pull.read_scalar
        when "license"
          check_duplicate(@license, "license", line, column)
          @license = pull.read_scalar
        when "crystal"
          check_duplicate(@crystal, "crystal", line, column)
          @crystal = pull.read_scalar
        when "authors"
          check_duplicate(@authors, "authors", line, column)
          pull.read_empty_or do
            pull.each_in_sequence do
              authors << Author.new(pull.read_scalar)
            end
          end
        when "dependencies"
          check_duplicate(@dependencies, "dependencies", line, column)
          pull.read_empty_or do
            pull.each_in_mapping do
              dependencies << Dependency.from_yaml(pull)
            end
          end
        when "development_dependencies"
          check_duplicate(@development_dependencies, "development_dependencies", line, column)
          pull.read_empty_or do
            pull.each_in_mapping do
              development_dependencies << Dependency.from_yaml(pull)
            end
          end
        when "targets"
          check_duplicate(@targets, "targets", line, column)
          pull.read_empty_or do
            pull.each_in_mapping do
              targets << Target.new(pull)
            end
          end
        when "executables"
          check_duplicate(@executables, "executables", line, column)
          pull.read_empty_or do
            pull.each_in_sequence do
              executables << pull.read_scalar
            end
          end
        when "libraries"
          check_duplicate(@libraries, "libraries", line, column)
          pull.read_empty_or do
            pull.each_in_mapping do
              libraries << Library.new(pull)
            end
          end
        when "scripts"
          check_duplicate(@scripts, "scripts", line, column)
          pull.read_empty_or do
            pull.each_in_mapping do
              scripts[pull.read_scalar] = pull.read_scalar
            end
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
      @read_from_yaml = true
    end

    private def check_duplicate(argument, name, line, column)
      unless argument.nil?
        raise YAML::ParseException.new("duplicate attribute #{name.inspect}", line, column)
      end
    end

    def name=(@name : String)
    end

    def version=(@version : Version)
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

    def executables
      @executables ||= [] of String
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
          "https://spdx.org/licenses/#{license}"
        end
      end
    end
  end
end
