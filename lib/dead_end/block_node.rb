# frozen_string_literal: true

module DeadEnd
  # A core data structure
  #
  # A block node keeps a reference to the block above it
  # and below it. In addition a block can "capture" another
  # block. Block nodes are treated as immutable(ish) so when that happens
  # a new node is created that contains a reference to all the blocks it was
  # derived from. These are known as a block's "parents".
  #
  # If you walk the parent chain until it ends you'll end up with nodes
  # representing individual lines of code (generated from a CodeLine).
  #
  # An important concept in a block is that it knows how it is "leaning"
  # based on it's internal LexPairDiff. If it's leaning `:left` that means
  # it needs to capture something to it's right/down to be balanced again.
  #
  # Note: that that the capture method is on BlockDocument since it needs to
  # retain a valid reference to it's root.
  #
  # Another important concept is that blocks know their current indentation
  # as well as can accurately derive their "next" indentation for when/if
  # they're expanded. To be calculated a nodes above and below blocks must
  # be accurately assigned. So this property cannot be calculated at creation
  # time.
  class BlockNode
    # Helper to create a block from other blocks
    #
    #   parents = node.parents
    #   expect(parents[0].leaning).to eq(:left)
    #   expect(parents[2].leaning).to eq(:right)
    #
    #   block = BlockNode.from_blocks([parents[0], parents[2]])
    #   expect(block.leaning).to eq(:equal)
    def self.from_blocks(parents, above: nil, below: nil)
      lines = []
      while parents.length == 1 && parents.first.parents.any?
        parents = parents.first.parents
      end
      indent = parents.first.indent
      lex_diff = LexPairDiff.new_empty
      parents.each do |block|
        lines.concat(block.lines)
        lex_diff.concat(block.lex_diff)
        indent = block.indent if block.indent < indent
        block.delete
      end

      above ||= parents.first.above
      below ||= parents.last.below


      parents = [] if parents.length == 1

      node = BlockNode.new(
        lines: lines,
        lex_diff: lex_diff,
        indent: indent,
        parents: parents
      )

      node.above = above
      node.below = below
      node
    end

    attr_accessor :above, :below, :left, :right, :parents
    attr_reader :lines, :start_index, :end_index, :lex_diff, :indent, :starts_at, :ends_at

    def initialize(lines:, indent:, next_indent: nil, lex_diff: nil, parents: [])
      lines = Array(lines)
      @lines = lines
      @deleted = false

      @end_index = lines.last.index
      @start_index = lines.first.index
      @indent = indent
      @next_indent = next_indent

      @starts_at = @start_index + 1
      @ends_at = @end_index + 1

      @parents = parents

      if lex_diff.nil?
        set_lex_diff_from(@lines)
      else
        @lex_diff = lex_diff
      end
    end

    # Used to determine when to expand up in building
    # a tree. Also used to calculate the `next_indent`.
    #
    # There is a tight coupling between the two concepts
    # as the `next_indent` is used to determine node expansion
    # priority
    def expand_above?(with_indent: indent)
      return false if above.nil?

      # Above node needs to expand up too, make sure that happens first
      return false if above.leaf? && above.leaning == :right

      # Special case first move
      if leaf?
        # We need to expand down on first move, not up
        return false if leaning == :left

        # If we're unbalanced both ways, prefer to be unbalanced in only one way
        return true if leaning == :both && above.leaning == :left
      end

      # Capturing a :left or :both could change our leaning, do so with caution
      if above.leaning == :left || above.leaning == :both
        above.indent >= with_indent
      else
        true
      end
    end

    # Used to determine when to expand down in building
    # a tree. Also used to calculate the `next_indent`.
    #
    # There is a tight coupling between the two concepts
    # as the `next_indent` is used to determine node expansion
    # priority
    def expand_below?(with_indent: indent)
      return false if below.nil?

      # Below node needs to expand down, make sure that happens first
      return false if below.leaf? && below.leaning == :left

      # Special case first move
      if leaf?
        # We need to expand up on first move, not down
        return false if leaning == :right

        # If we're unbalanced both ways, prefer to be unbalanced in only one way
        return true if leaning == :both && below.leaning == :right
      end

      # Capturing a :right or both could change our leaning, do so with caution
      if below.leaning == :right || below.leaning == :both
        below.indent >= with_indent
      else
        true
      end
    end

    def leaf?
      parents.empty?
    end

    # Given a node, it's above and below links
    # returns the next indentation.
    #
    # The algorithm for the logic follows:
    #
    # Expand given the current rules and current indentation
    # keep doing that until we can't anymore. When we can't
    # then pick the lowest indentation that will capture above
    # and below blocks.
    #
    # The results of this algorithm are tightly coupled to
    # tree building and therefore search.
    def self.next_indent(above, node, below)
      return node.indent if node.expand_above? || node.expand_below?

      value = if above
        if below
          case above.indent <=> below.indent
          when 1 then below.indent
          when 0 then above.indent
          when -1 then above.indent
          end
        else
          above.indent
        end
      elsif below
        below.indent
      else
        node.indent
      end

      value > node.indent ? node.indent : value
    end

    # Calculating the next_indent must be done after above and below
    # have been assigned (otherwise we would have a race condition).
    def next_indent
      @next_indent ||= self.class.next_indent(above, self, below)
    end

    # It's useful to be able to mark a node as deleted without having
    # to iterate over a data structure to remove it.
    #
    # By storing a deleted state of a node we can instead lazilly ignore it
    # as needed. This is a performance optimization.
    def delete
      @deleted = true
    end

    def deleted?
      @deleted
    end

    # Code within a given node is not syntatically valid
    def invalid?
      !valid?
    end

    # Code within a given node is syntatically valid
    #
    # Value is memoized for performance
    def valid?
      return @valid if defined?(@valid)

      @valid = DeadEnd.valid?(@lines.join)
    end

    # Opposite of `balanced?`
    def unbalanced?
      !balanced?
    end

    # A node that is `leaning == :equal` is determined to be "balanced".
    #
    # Alternative states include :left, :right, or :both
    def balanced?
      @lex_diff.balanced?
    end

    # Returns the direction a block is leaning
    #
    # States include :equal, :left, :right, and :both
    def leaning
      @lex_diff.leaning
    end

    def to_s
      @lines.join
    end

    # Determines priority of node within a priority data structure
    # (such as a priority queue).
    #
    # This is tightly coupled to tree building and search.
    #
    # It's also a performance sensitive area. An optimization
    # not yet taken would be to re-encode the same data as a string
    # so a node with next indent of 8, current indent of 10 and line
    # of 100 might possibly be encoded as `008001000100` which would
    # sort the same as this logic. Preliminary benchmarks indicate a
    # rough 2x speedup
    def <=>(other)
      case next_indent <=> other.next_indent
      when 1 then 1
      when -1 then -1
      when 0
        case indent <=> other.indent
        when 1 then 1
        when -1 then -1
        when 0

          end_index <=> other.end_index
        end
      end
    end

    def hidden?
      false
    end

    # Provide meaningful diffs in rspec
    def inspect
      "#<DeadEnd::BlockNode 0x000000010cbfelol range=#{@start_index}..#{@end_index}, @indent=#{indent}, @next_indent=#{next_indent}, @parents=#{@parents.inspect}>"
    end

    # Generate a new lex pair diff given an array of lines
    private def set_lex_diff_from(lines)
      @lex_diff = LexPairDiff.new_empty
      lines.each do |line|
        @lex_diff.concat(line.lex_diff)
      end
    end

    # Needed for meaningful rspec assertions
    def ==(other)
      return false if other.nil?

      @lines == other.lines && @indent == other.indent && next_indent == other.next_indent && @parents == other.parents
    end
  end
end