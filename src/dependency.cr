module Shards
  class Dependency < Hash(String, String)
    property :name

    def self.new(pull : YAML::PullParser)
      dependency = new(pull.read_scalar)
      pull.read_mapping_start

      while pull.kind != YAML::EventKind::MAPPING_END
        dependency[pull.read_scalar] = pull.read_scalar
      end

      pull.read_next
      dependency
    #rescue YAML::ParseException
    #  raise Exception.new("Invalid dependency definition at #{ ex.line_number }:#{ ex.column_number }")
    end

    def initialize(@name)
      super()
    end

    # DEPRECATED: with no replacement
    def initialize(@name, config)
      super()
      config.each { |k, v| self[k.to_s] = v.to_s }
    end

    def version
      fetch("version", "*")
    end

    def refs
      self["branch"]? || self["tag"]? || self["commit"]?
    end

    def inspect(io)
      io << "#<" << self.class.name << " {" << name << " => "
      super
      io << "}>"
    end
  end
end
