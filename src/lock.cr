require "./ext/yaml"
require "./dependency"
require "./package"

module Shards
  module Lock
    def self.from_file(path)
      raise Error.new("Missing #{File.basename(path)}") unless File.exists?(path)
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
                dependencies << Dependency.from_yaml(pull, is_lock: true)
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
      raise Error.new("Invalid #{LOCK_FILENAME}. Please delete it and run install again.")
    ensure
      pull.close if pull
    end

    def self.write(packages : Array(Package), path : String)
      File.open(path, "w") do |file|
        write(packages, file)
      end
    end

    def self.write(packages : Array(Package), io : IO)
      io << "version: 1.0\n"
      io << "shards:\n"

      packages.sort_by!(&.name).each do |package|
        key = package.resolver.class.key

        io << "  " << package.name << ":\n"
        io << "    " << key << ": " << package.resolver.source << '\n'
        io << "    version: " << package.version.value << '\n'
        io << '\n'
      end
    end
  end
end
