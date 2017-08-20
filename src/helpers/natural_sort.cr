module Shards
  module Helpers
    module NaturalSort
      EXTRACT_ALPHA_OR_NUMBER_GROUP = /([A-Za-z]+|[\d]+)/
      IS_NUMBER_STRING = /\A\d+\Z/

      def natural_sort(a, b)
        NaturalSort.sort(a, b)
      end

      def self.sort(a, b)
        ia = ib = 0
        la, lb = a.size, b.size

        loop do
          return 0 if ia > la
          return 0 unless a[ia .. -1] =~ EXTRACT_ALPHA_OR_NUMBER_GROUP
          aaa = $1
          ia += $1.size + 1

          return 0 if ib > lb
          return 0 unless b[ib .. -1] =~ EXTRACT_ALPHA_OR_NUMBER_GROUP
          bbb = $1
          ib += $1.size + 1

          if aaa =~ IS_NUMBER_STRING && bbb =~ IS_NUMBER_STRING
            aaa, bbb = aaa.to_i64, bbb.to_i64
            ret = bbb <=> aaa
          else
            ret = bbb <=> aaa
          end

          return ret unless ret == 0
        end
      end
    end
  end
end
