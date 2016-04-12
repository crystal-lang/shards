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
      super "Outdated #{ LOCK_FILENAME } (#{message}). Please run shards update instead."
    end
  end

  class InvalidLock < Error
    def initialize
      super "Unsupported #{ LOCK_FILENAME }. It was likely generated from a newer version of Shards."
    end
  end

  class ParseError < Error
    getter input : String
    getter filename : String
    getter line_number : Int32
    getter column_number : Int32

    def initialize(message, @input, @filename, line_number, column_number)
      @line_number = line_number.to_i
      @column_number = column_number.to_i
      super message
    end

    def to_s(io)
      io.puts "in #{ filename }:#{ line_number }: #{ self.class.name }: #{ message }"
      io.puts

      lines = input.split('\n')
      from = line_number - 2
      from = 0 if from < 0

      lines[from .. line_number].each_with_index do |line, i|
        io.puts "  #{ i + 1 }. #{ line }"
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
