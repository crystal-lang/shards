require "yaml"
require "./dependency"
require "./errors"

module Shards
  class Spec
    class Author
      property :name
      property :email

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

    # :nodoc:
    class Dependencies < Array(Dependency)
      def self.new(pull : YAML::PullParser)
        pull.read_mapping_start
        dependencies = new

        while pull.kind != YAML::EventKind::MAPPING_END
          dependencies << Dependency.new(pull)
        end

        pull.read_next
        dependencies
      #rescue ex : YAML::ParseException
      #  raise Exception.new("Invalid dependencies definition at #{ ex.line_number }:#{ ex.column_number }")
      end
    end

    def self.from_file(path)
      path = File.join(path, SPEC_FILENAME) if File.directory?(path)
      raise Error.new("Missing #{ File.basename(path) }") unless File.exists?(path)
      from_yaml(File.read(path))
    end

    yaml_mapping({
      name: { type: String },
      version: { type: String },
      description: { type: String, nilable: true },
      license: { type: String, nilable: true },
      authors: { type: Array(Author), nilable: true },
      scripts: { type: Hash(String, String), nilable: true },
      dependencies: { type: Dependencies, nilable: true },
      development_dependencies: { type: Dependencies, nilable: true },
    })

    getter! :version

    def initialize(@name : String)
    end

    def authors
      @authors ||= [] of Author
    end

    def dependencies
      @dependencies ||= Dependencies.new
    end

    def development_dependencies
      @development_dependencies ||= Dependencies.new
    end

    def script(name)
      if scripts = self.scripts
        scripts[name]?
      end
    end

    def license_url
      if license = self.license
        if license =~ %r(https?://)
          license
        else
          "http://opensource.org/licenses/#{ license }"
        end
      end
    end
  end
end
