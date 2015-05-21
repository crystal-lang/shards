require "./natural_sort"

module Shards
  module Helpers
    module Versions
      include NaturalSort

      def resolve_versions(versions, requirements)
        matches = requirements
          .map { |requirement| resolve_requirement(versions, requirement) }
          .inject(versions) { |a, e| a & e }
      end

      def resolve_requirement(versions, requirement)
        case requirement
        when "*", ""
          versions

        when /~>(.+)/
          ver = $1.strip
          vver = ver[0 ... ver.rindex(".").to_i]
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
