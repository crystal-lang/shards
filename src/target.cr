module Shards
  class Target
    getter name : String
    property main : String
    property options : Array(String)

    def initialize(@name)
      super()
      @main = ""
      @options = [] of String
    end

    def cmd
      "crystal build #{@main} #{@options.join(" ")}"
    end
  end
end
