require "./ext/yaml"
require "./dependency"
require "./package"

module Shards
  class Lock
    property version : String
    property shards : Array(Package)

    CURRENT_VERSION = "2.0"

    def initialize(@version : String, @shards : Array(Package))
    end

    def self.from_file(path)
      raise Error.new("Missing #{File.basename(path)}") unless File.exists?(path)
      from_yaml(File.read(path))
    end

    def self.from_yaml(str)
      shards = [] of Package

      pull = YAML::PullParser.new(str)
      pull.read_stream do
        pull.read_document do
          pull.read_mapping do
            key, version = pull.read_scalar, pull.read_scalar

            unless key == "version" && version.in?("1.0", "2.0")
              raise InvalidLock.new
            end

            case key = pull.read_scalar
            when "shards"
              pull.each_in_mapping do
                # Shards are parsed as dependencies to keep
                # compatiblity with version 1.0. Calls to `as_package?`
                # will use the resolver to convert potential references
                # to explicit versions used in 2.0 format.
                dep = Dependency.from_yaml(pull)
                if package = dep.as_package?
                  shards << package
                else
                  Log.warn { "Lock for shard \"#{dep.name}\" is invalid" }
                end
              end
            else
              pull.raise "No such attribute #{key} in lock version #{version}"
            end

            Lock.new(version, shards)
          end
        end
      end
    rescue ex : YAML::ParseException
      raise Error.new("Invalid #{LOCK_FILENAME}. Please delete it and run install again.")
    ensure
      pull.close if pull
    end

    def self.write(packages : Array(Package), override_path : String?, path : String)
      File.open(path, "w") do |file|
        write(packages, override_path, file)
      end
    end

    def self.write(packages : Array(Package), override_path : String?, io : IO)
      if packages.any?(&.is_override)
        io << "# NOTICE: This lockfile contains some overrides from #{override_path}\n"
      end
      io << "version: #{CURRENT_VERSION}\n"
      io << "shards:\n"

      packages.sort_by!(&.name).each do |package|
        key = package.resolver.class.key

        io << "  " << package.name << ":#{package.is_override ? " # Overridden" : nil}\n"
        io << "    " << key << ": " << package.resolver.source << '\n'
        io << "    version: " << package.version.value << '\n'
        io << '\n'
      end
    end
  end
end
