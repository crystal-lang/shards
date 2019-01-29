require "minitest/autorun"
require "../src/solver/sat"

class Shards::Solver
  class SATTest < Minitest::Test
    def test_sat_solver
      data = <<-CLAUSES
        # Assign at least one colour to region 1
        R1 B1 G1 Y1

        # But no more than one colour
        ~R1 ~B1
        ~R1 ~G1
        ~R1 ~Y1
        ~B1 ~G1
        ~B1 ~Y1
        ~G1 ~Y1

        # Similarly for region 2
        R2 B2 G2 Y2
        ~R2 ~B2
        ~R2 ~G2
        ~R2 ~Y2
        ~B2 ~G2
        ~B2 ~Y2
        ~G2 ~Y2

        # Make sure regions 1 and 2 are not coloured the same since they are neighbours
        ~R1 ~R2
        ~B1 ~B2
        ~G1 ~G2
        ~Y1 ~Y2
        CLAUSES

      solutions = [
        %w(~R1 ~B1 ~G1 Y1 ~R2 ~B2 G2 ~Y2),
        %w(~R1 ~B1 ~G1 Y1 ~R2 B2 ~G2 ~Y2),
        %w(~R1 ~B1 ~G1 Y1 R2 ~B2 ~G2 ~Y2),
        %w(~R1 ~B1 G1 ~Y1 ~R2 ~B2 ~G2 Y2),
        %w(~R1 ~B1 G1 ~Y1 ~R2 B2 ~G2 ~Y2),
        %w(~R1 ~B1 G1 ~Y1 R2 ~B2 ~G2 ~Y2),
        %w(~R1 B1 ~G1 ~Y1 ~R2 ~B2 ~G2 Y2),
        %w(~R1 B1 ~G1 ~Y1 ~R2 ~B2 G2 ~Y2),
        %w(~R1 B1 ~G1 ~Y1 R2 ~B2 ~G2 ~Y2),
        %w(R1 ~B1 ~G1 ~Y1 ~R2 ~B2 ~G2 Y2),
        %w(R1 ~B1 ~G1 ~Y1 ~R2 ~B2 G2 ~Y2),
        %w(R1 ~B1 ~G1 ~Y1 ~R2 B2 ~G2 ~Y2),
      ]
      sat = SAT.from_io(IO::Memory.new(data))

      sat.solve(brief: false) do |solution|
        assert_equal solutions.shift, solution
      end

      assert_empty solutions
    end

    def test_simple_dependencies
      data = <<-CLAUSES
      # package to install:
      a

      # a -> (b, c, d)
      ~a b
      ~a c
      ~a z

      # b -> d
      ~b d

      # c -> (d | e, f | g)
      ~c d e
      ~c f g

      # d ! e
      ~d ~e

      # y -> z
      ~y z
      CLAUSES

      solutions = [
        %w(a b c z d g),
        %w(a b c z d g y),
        %w(a b c z d f),
        %w(a b c z d f y),
        %w(a b c z d f g),
        %w(a b c z d f g y),
      ]

      sat = SAT.from_io(IO::Memory.new(data))
      sat.solve do |solution|
        assert_equal solutions.shift, solution
      end
      assert_empty solutions
    end

    def test_versions
      # libraries:
      #
      # foo:
      #    pg: ~> 0.2.0
      #    rome: ~> 0.2
      #
      # rome 0.3.0:
      #    db: ~> 0.2.0
      #
      # rome 0.2.0:
      #    db: ~> 0.2.0
      #
      # rome 0.1.0:
      #    db: ~> 0.1.0
      #
      # pg 0.2.0:
      #    db: ~> 0.2.0
      #
      # pg 0.1.0:
      #    db: ~> 0.1.0
      #
      # db 0.1.0:
      # db 0.1.1:
      # db 0.1.0:
      data = <<-CLAUSES
      # package to install dependencies for:
      foo

      # foo -> (pg:0.2.0, rome:0.3.0 | rome:0.2.0)
      ~foo pg:0.2.0
      ~foo rome:0.3.0 rome:0.2.0

      # rome:0.3.0 -> db:0.2.0
      ~rome:0.3.0 db:0.2.0

      # rome:0.2.0 -> db:0.2.0
      ~rome:0.2.0 db:0.2.0

      # rome:0.1.0 -> (db:0.1.1 | db:0.1.0)
      ~rome:0.1.0 db:0.1.1 db:0.1.0

      # pg:0.2.0 -> db:0.2.0
      ~pg:0.2.0 db:0.2.0

      # pg:0.1.0 -> (db:0.1.0 | db:0.1.1)
      ~pg:0.1.0 db:0.1.1 db:0.1.0

      # conflicts (want at most 1 version per package):
      ~rome:0.3.0 ~rome:0.2.0
      ~rome:0.3.0 ~rome:0.1.0
      ~rome:0.2.0 ~rome:0.1.0

      ~pg:0.2.0 ~pg:0.1.0

      ~db:0.2.0 ~db:0.1.1
      ~db:0.2.0 ~db:0.1.0
      ~db:0.1.1 ~db:0.1.0
      CLAUSES

      solutions = [
        %w(foo pg:0.2.0 rome:0.2.0 db:0.2.0),
        %w(foo pg:0.2.0 rome:0.3.0 db:0.2.0),
      ]

      sat = SAT.from_io(IO::Memory.new(data))
      sat.solve do |solution|
        assert_equal solutions.shift, solution
      end

      assert_empty solutions
    end

    def test_versions2
      # libraries:
      #
      # foo:
      #    pg: ~> 0.1.0
      #    rome: ~> 0.1
      #
      # rome 0.3.0:
      #    db: ~> 0.2.0
      #
      # rome 0.2.0:
      #    db: ~> 0.2.0
      #
      # rome 0.1.0:
      #    db: ~> 0.1.0
      #
      # pg 0.2.0:
      #    db: ~> 0.2.0
      #
      # pg 0.1.0:
      #    db: ~> 0.1.0
      #
      # db 0.1.0:
      # db 0.1.1:
      # db 0.1.0:
      data = <<-CLAUSES
      # package to install dependencies for:
      foo

      # foo -> (pg:0.2.0, rome:0.3.0 | rome:0.2.0 | rome:0.1.0)
      ~foo pg:0.1.0
      ~foo rome:0.3.0 rome:0.2.0 rome:0.1.0

      # rome:0.3.0 -> db:0.2.0
      ~rome:0.3.0 db:0.2.0

      # rome:0.2.0 -> db:0.2.0
      ~rome:0.2.0 db:0.2.0

      # rome:0.1.0 -> (db:0.1.1 | db:0.1.0)
      ~rome:0.1.0 db:0.1.1 db:0.1.0

      # pg:0.2.0 -> db:0.2.0
      ~pg:0.2.0 db:0.2.0

      # pg:0.1.0 -> (db:0.1.0 | db:0.1.1)
      ~pg:0.1.0 db:0.1.1 db:0.1.0

      # conflicts (want at most 1 version per package):
      ~rome:0.3.0 ~rome:0.2.0
      ~rome:0.3.0 ~rome:0.1.0
      ~rome:0.2.0 ~rome:0.1.0

      ~pg:0.2.0 ~pg:0.1.0

      ~db:0.2.0 ~db:0.1.1
      ~db:0.2.0 ~db:0.1.0
      ~db:0.1.1 ~db:0.1.0
      CLAUSES

      solutions = [
        %w(foo pg:0.1.0 rome:0.1.0 db:0.1.0),
        %w(foo pg:0.1.0 rome:0.1.0 db:0.1.1),
      ]

      sat = SAT.from_io(IO::Memory.new(data))
      sat.solve do |solution|
        assert_equal solutions.shift, solution
      end

      assert_empty solutions
    end

    def test_versions3
      # libraries:
      #
      # foo:
      #    pg: ~> 0.1.0
      #    rome: ~> 0.1
      #
      # rome 0.3.0:
      #    db: ~> 0.2.0
      #
      # rome 0.2.0:
      #    db: ~> 0.2.0
      #
      # rome 0.1.0:
      #    db: ~> 0.1.0
      #
      # pg 0.2.0:
      #    db: ~> 0.2.0
      #
      # pg 0.1.0:
      #    db: ~> 0.1.0
      #
      # db 0.1.0:
      # db 0.1.1:
      # db 0.1.0:
      data = <<-CLAUSES
      # package to install dependencies for:
      foo

      # foo -> (pg:0.1.0, rome:0.3.0)
      ~foo pg:0.1.0
      ~foo rome:0.3.0

      # rome:0.3.0 -> db:0.2.0
      ~rome:0.3.0 db:0.2.0

      # rome:0.2.0 -> db:0.2.0
      ~rome:0.2.0 db:0.2.0

      # rome:0.1.0 -> (db:0.1.1 | db:0.1.0)
      ~rome:0.1.0 db:0.1.1 db:0.1.0

      # pg:0.2.0 -> db:0.2.0
      ~pg:0.2.0 db:0.2.0

      # pg:0.1.0 -> (db:0.1.0 | db:0.1.1)
      ~pg:0.1.0 db:0.1.1 db:0.1.0

      # conflicts (want at most 1 version per package):
      ~rome:0.3.0 ~rome:0.2.0
      ~rome:0.3.0 ~rome:0.1.0
      ~rome:0.2.0 ~rome:0.1.0

      ~pg:0.2.0 ~pg:0.1.0

      ~db:0.2.0 ~db:0.1.1
      ~db:0.2.0 ~db:0.1.0
      ~db:0.1.1 ~db:0.1.0
      CLAUSES

      solutions = [] of String

      sat = SAT.from_io(IO::Memory.new(data))
      sat.solve do |solution|
        assert_equal solutions.shift?, solution
      end

      assert_empty solutions
    end
  end
end
