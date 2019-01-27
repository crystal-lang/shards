# Crystal port of simple-sat by Sahand Saba distributed under the MIT License.
# - https://github.com/sahands/simple-sat/
# - https://sahandsaba.com/understanding-sat-by-implementing-a-simple-sat-solver-in-python.html

module Shards
  class SAT
    alias Literal = Int32
    alias Clause = Array(Literal)

    enum Assignment : Int8
      NOT_SELECTED = 0
      SELECTED = 1
      UNDEFINED = -1
    end

    def self.from_io(io : IO) : SAT
      new.tap do |sat|
        while line = io.gets
          next if line.empty? || line.starts_with?('#')
          sat.add_clause(line)
        end
      end
    end

    def self.from_file(path : String) : SAT
      File.open(path) { |f| from_io(f) }
    end

    def initialize
      @clauses = Array(Clause).new
      @table = Hash(String, Literal).new
      @variables = Array(String).new
    end

    def add_clause(str : String) : Nil
      add_clause(str.split)
    end

    def add_clause(ary : Array(String)) : Nil
      clause = ary.map do |literal|
        negated = literal.starts_with?('~') ? 1 : 0
        variable = literal[negated..-1]

        unless @table.has_key?(variable)
          @table[variable] = @variables.size
          @variables << variable
        end

        @table[variable] << 1 | negated
      end

      clause.uniq!
      @clauses << clause
    end

    private def literal_to_s(literal : Literal) : String
      String.build { |str| literal_to_s(str, literal) }
    end

    private def literal_to_s(io : IO, literal : Literal) : Nil
      io << '~' unless literal & 1 == 0
      io << @variables[literal >> 1]
    end

    private def clause_to_s(clause : Clause) : String
      String.build do |str|
        clause.each_with_index do |literal, index|
          str << ' ' unless index == 0
          literal_to_s(str, literal)
        end
      end
    end

    private def assignment_to_s(assignment, brief = false)
      String.build do |str|
        assignment.each_with_index do |a, index|
          if a.selected?
            str << @variables[index] << ' '
          elsif !brief && a.not_selected?
            str << '~' << @variables[index] << ' ' unless brief
          end
        end
      end
    end

    private def to_variables(result, assignment, brief = false)
      result.clear

      assignment.each_with_index do |a, index|
        if a.selected?
          result << @variables[index]
        elsif !brief && a.not_selected?
          result << "~#{@variables[index]}"
        end
      end
    end

    # Solves SAT and yields proposed solution.
    #
    # Reuses the yielded array for performance reasons (avoids many
    # allocations); you must duplicate the array if you want to memorize a
    # solution. For example:
    #
    # ```
    # solution = nil
    # ast.solve { |proposal| solution = proposal.dup }
    # ```
    def solve(brief = true, verbose = false) : Nil
      watchlist = setup_watchlist
      assignment = Array(Assignment).new(@variables.size) { Assignment::UNDEFINED }

      result = [] of String

      solve(watchlist, assignment, 0, verbose) do |solution|
        to_variables(result, solution, brief)
        yield result
      end
    end

    # Iteratively solve SAT by assigning to variables d, d+1, ..., n-1.
    # Assumes variables 0, ..., d-1 are assigned so far.
    private def solve(watchlist, assignment, d, verbose)
      # The state list keeps track of what values for which variables we have
      # tried so far. A value of 0 means nothing has been tried yet, a value of
      # 1 means False has been tried but not True, 2 means True but not False,
      # and 3 means both have been tried.
      n = @variables.size
      state = Array(Literal).new(n) { Literal.new(0) }

      loop do
        if d == n
          yield assignment
          d -= 1
          next
        end

        # Let's try assigning a value to 'v'. Here would be the place to insert
        # heuristics of which value to try first.
        tried_something = false

        {0, 1}.each do |a|
          if (state[d] >> a) & 1 == 0
            STDERR.puts "Trying #{@variables[d]} = #{a}" if verbose

            tried_something = true

            # set the bit indicating 'a' has been tried for 'd':
            state[d] |= 1 << a
            assignment[d] = Assignment.from_value(a)

            if !update_watchlist(watchlist, (d << 1) | a, assignment, verbose)
              assignment[d] = Assignment::UNDEFINED
            else
              d += 1
              break
            end
          end
        end

        unless tried_something
          if d == 0
            # can't backtrack further, no solutions:
            return
          end

          # backtrack:
          state[d] = 0
          assignment[d] = Assignment::UNDEFINED
          d -= 1
        end
      end
    end

    private def setup_watchlist
      watchlist = Array.new(@variables.size * 2) { Deque(Clause).new }
      @clauses.each { |clause| watchlist[clause[0]] << clause }
      watchlist
    end

    private def dump_watchlist(watchlist)
      STDERR.puts "Current watchlist:"

      watchlist.each_with_index do |w, l|
        STDERR << literal_to_s(l) << ": "
        STDERR.puts w.map { |c| clause_to_s(c) }.join(", ")
      end
    end

    # Updates the watch list after literal 'false_literal' was just assigned
    # `false`, by making any clause watching false_literal watch something else.
    # Returns `false` if it's impossible to do so, meaning a clause is
    # contradicted by the current assignment.
    private def update_watchlist(watchlist, false_literal, assignment, verbose)
      while clause = watchlist[false_literal].first?
        found_alternative = false

        clause.each do |alternative|
          v = alternative >> 1
          a = alternative & 1
          av = assignment[v]

          if av.undefined? || av.value == a ^ 1
            found_alternative = true
            watchlist[false_literal].shift?
            watchlist[alternative] << clause
            break
          end
        end

        unless found_alternative
          if verbose
            dump_watchlist(watchlist)
            STDERR.puts "Current assignment: #{assignment_to_s(assignment)}"
            STDERR.puts "Clause #{clause_to_s(clause)} contradicted."
          end
          return false
        end
      end

      return true
    end
  end
end
