module Shards
  class Target < Hash(String, String)
    property name : String

    def initialize(@name)
      super()
    end

    def main
      self["main"]
    end
  end
end
