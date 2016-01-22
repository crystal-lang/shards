require "./natural_sort"

module Shards
  module Helpers
    module Versions
      include NaturalSort

      def resolve_versions(versions, requirements)
        requirements
          .map { |requirement| resolve_requirement(versions, requirement) }
          .reduce(versions) { |a, e| a & e }
          .sort { |a, b| natural_sort(a, b) }
      end

      def resolve_requirement(versions, requirement)
        case requirement
        when "*", ""
          versions

        when /~>(.+)/
          ver = $1.strip
          vver = if idx = ver.rindex(".")
                   ver[0 ... idx]
                 else
                   ver
                 end
          versions.select { |v| v.starts_with?(vver) && (natural_sort(v, ver) <= 0) }

        when />=(.+)/
          ver = $1.strip
          versions.select { |v| natural_sort(v, ver) <= 0 }

        when /<=(.+)/
          ver = $1.strip
          versions.select { |v| natural_sort(v, ver) >= 0 }

        when />(.+)/
          ver = $1.strip
          versions.select { |v| natural_sort(v, ver) < 0 }

        when /<(.+)/
          ver = $1.strip
          versions.select { |v| natural_sort(v, ver) > 0 }

        else
          ver = requirement.strip
          versions.select { |v| v == ver }

        end
      end
    end
  end
end
