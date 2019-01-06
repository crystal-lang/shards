require "./natural_sort"

module Shards
  module Helpers
    module Versions
      def self.resolve_versions(versions, requirements)
        requirements
          .map { |requirement| resolve_requirement(versions, requirement) }
          .reduce(versions) { |a, e| a & e }
          .sort { |a, b| NaturalSort.sort(a, b) }
      end

      def self.resolve_requirement(versions, requirement)
        case requirement
        when "*", ""
          versions
        when /~>(.+)/
          ver = $1.strip
          vver = if idx = ver.rindex('.')
                   ver[0...idx]
                 else
                   ver
                 end
          versions.select { |v| v.starts_with?(vver) && (NaturalSort.sort(v, ver) <= 0) }
        when />=(.+)/
          ver = $1.strip
          versions.select { |v| NaturalSort.sort(v, ver) <= 0 }
        when /<=(.+)/
          ver = $1.strip
          versions.select { |v| NaturalSort.sort(v, ver) >= 0 }
        when />(.+)/
          ver = $1.strip
          versions.select { |v| NaturalSort.sort(v, ver) < 0 }
        when /<(.+)/
          ver = $1.strip
          versions.select { |v| NaturalSort.sort(v, ver) > 0 }
        else
          ver = requirement.strip
          versions.select { |v| v == ver }
        end
      end
    end
  end
end
