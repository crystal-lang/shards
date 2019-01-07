require "./natural_sort"

module Shards
  module Helpers
    module Versions
      include NaturalSort

      def resolve_versions(versions, requirements)
        matching_versions = requirements
          .map { |requirement| resolve_requirement(versions, requirement) }
          .reduce(versions) { |a, e| a & e }
        natural_sort(matching_versions)
      end

      def resolve_requirement(versions, requirement)
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
          versions.select do |v|
            v.starts_with?(vver) &&
              !v[vver.size]?.try(&.ascii_alphanumeric?) &&
              (natural_compare(v, ver) <= 0)
          end

        when />=(.+)/
          ver = $1.strip
          versions.select { |v| natural_compare(v, ver) <= 0 }

        when /<=(.+)/
          ver = $1.strip
          versions.select { |v| natural_compare(v, ver) >= 0 }

        when />(.+)/
          ver = $1.strip
          versions.select { |v| natural_compare(v, ver) < 0 }

        when /<(.+)/
          ver = $1.strip
          versions.select { |v| natural_compare(v, ver) > 0 }

        else
          ver = requirement.strip
          versions.select { |v| v == ver }
        end
      end
    end
  end
end
