module Shards
  class Groups < Array(String)
    def with(groups)
      groups.each do |group|
        push(group) unless includes?(group)
      end
    end

    def without(groups)
      groups.each { |group| delete(group) }
    end
  end
end
