require "./command"
require "../dependency_graph"

module Shards
  module Commands
    class Graph < Command
      def run
        graph = DependencyGraph.new
        graph.add(spec, development: !Shards.production?)

        graph.each do |pkg|
          print "  * "
          print pkg.name
          print ':'

          pkg.each_version do |version|
            print ' '
            print version
          end

          print '\n'
        end
      end
    end
  end
end
