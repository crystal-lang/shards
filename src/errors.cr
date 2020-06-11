module Shards
  class Error < ::Exception
  end

  class Conflict < Error
    getter package

    def initialize(@package : Package)
      super "Error resolving #{package.name} (#{package.requirements.join(", ")})"
    end
  end

  class LockConflict < Error
    def initialize(message)
      super "Outdated #{LOCK_FILENAME} (#{message}). Please run shards update instead."
    end
  end

  class InvalidLock < Error
    def initialize
      super "Unsupported #{LOCK_FILENAME}. It was likely generated from a newer version of Shards."
    end
  end

  class ParseError < Error
    getter input : String
    getter filename : String
    getter line_number : Int32
    getter column_number : Int32
    property resolver : Resolver?

    def initialize(message, @input, @filename, line_number, column_number)
      @line_number = line_number.to_i
      @column_number = column_number.to_i
      super message
    end

    def to_s(io)
      io << "Error in "
      if resolver = self.resolver
        resolver.name.inspect_unquoted(io)
        io << ':'
      end

      filename = self.filename
      {% if compare_versions(Crystal::VERSION, "0.35.0-0") > 0 %}
        filename = Path[filename].relative_to Dir.current
      {% else %}
        filename = filename.lchop(Dir.current + "/")
      {% end %}

      io.puts "#{filename}: #{message}"
      io.puts

      lines = input.split('\n')
      from = line_number - 3
      from = 0 if from < 0

      lines[from...line_number].each_with_index do |line, i|
        io.puts "  #{from + i + 1}. #{line}"
      end

      arrow = String.build do |s|
        s << "     "
        (column_number - 1).times { s << ' ' }
        s << '^'
      end
      io.puts arrow.colorize(:green).bold
      io.puts

      io.flush
    end
  end
end
