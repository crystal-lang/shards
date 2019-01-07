module Shards
  module Helpers
    module NaturalSort
      NON_ALPHANUMERIC = /[^a-zA-Z0-9]/

      def natural_sort(versions)
        versions.sort { |a, b| NaturalSort.compare(a, b) }
      end

      def natural_compare(a, b)
        NaturalSort.compare(a, b)
      end

      def self.compare(a, b)
        if a == b
          return 0
        end

        loop do
          # extract next segment from version number ("1.0.2" => "1" then "0" then "2"):
          a_segment, a = next_segment(a)
          b_segment, b = next_segment(b)

          # accept unbalanced version numbers ("1.0" == "1.0.0.0", "1.0" < "1.0.1")
          if a_segment.empty?
            only_zeroes_remaining(b_segment, b) { return 1 }
            return 0
          end

          # accept unbalanced version numbers ("1.0.0.0" == "1.0", "1.0.1" > "1.0")
          if b_segment.empty?
            only_zeroes_remaining(a_segment, a) { return -1 }
            return 0
          end

          # try to convert segments to numbers:
          a_num = a_segment.to_i?(whitespace: false)
          b_num = b_segment.to_i?(whitespace: false)

          # compare:
          ret =
            if a_num && b_num
              b_num <=> a_num
            else
              b_segment <=> a_segment
            end

          # if different return the result (older or newer), otherwise continue
          # to the next segment:
          return ret unless ret == 0
        end
      end

      private def self.next_segment(str)
        segment, _, str = str.partition(NON_ALPHANUMERIC)
        {segment, str}
      end

      private def self.only_zeroes_remaining(segment, str)
        unless segment.to_i?(whitespace: false) == 0
          yield
        end

        loop do
          segment, str = next_segment(str)
          break if segment.empty?

          unless segment.to_i?(whitespace: false) == 0
            yield
          end
        end
      end
    end
  end
end
