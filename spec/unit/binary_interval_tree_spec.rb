# frozen_string_literal: true

require_relative "../spec_helper"

module DeadEnd
  RSpec.describe BinaryIntervalTree do
    it "works as a binary search tree" do
      # tree = Containers::RubyRBTreeMap.new
      # tree.push(1, "a")
      # tree.push(2, "b")

      # expect(tree.get(1)).to be_truthy
      # expect(tree.get(9)).to be_falsey
    end

    it "Works as an interval tree" do
      tree = BinaryIntervalTree.new

      tree.push(RangeCmp.new(1..2), "a")
      tree.push(RangeCmp.new(2..2), "b")

      out = tree.search_all_covers_slow(RangeCmp.new(0..3))
      expect(out.count).to eq(2)
      expect(out.map(&:value).sort).to eq(["a", "b"].sort)
    end

    it "only finds ranges it contains" do
      tree = BinaryIntervalTree.new

      tree.push(RangeCmp.new(1..1), "a")
      tree.push(RangeCmp.new(5..5), "not_match")
      tree.push(RangeCmp.new(11..11), "b")

      out = tree.search_all_covers_slow(
        RangeCmp.new(0..3)
      )
      expect(out.count).to eq(1)
      expect(out.map(&:value)).to eq(["a"])

      out = tree.search_all_covers_slow(
        RangeCmp.new(10..12)
      )
      expect(out.count).to eq(1)
      expect(out.map(&:value)).to eq(["b"])
    end

    it "uses annotations to find nodes stored in reverse range" do
      tree = BinaryIntervalTree.new

      tree.push(RangeCmpRev.new(1..1), "a")
      tree.push(RangeCmpRev.new(5..5), "not_match")
      tree.push(RangeCmpRev.new(11..11), "b")

      out = tree.search_all_covers_slow(
        RangeCmpRev.new(0..3)
      )
      expect(out.count).to eq(1)
      expect(out.map(&:value)).to eq(["a"])

      out = tree.search_all_covers_slow(
        RangeCmpRev.new(10..12)
      )
      expect(out.count).to eq(1)
      expect(out.map(&:value)).to eq(["b"])
    end

    it "uses annotations to improve search" do
      # tree = BinaryIntervalTree::Debug.new
      # [
      #   20..36, # 0
      #   29..99, # 1
      #   3..41, # 2
      #   0..1, # 3
      #   10..15 # 4
      # ].each.with_index do |range, i|
      #   tree.push(RangeCmp.new(range), i)
      # end

      # out = tree.search_overlap(
      #   RangeCmp.new(20..36)
      # )
      # expect(out.map(&:value)).to eq([0])

      # out = tree.search_overlap(
      #   RangeCmp.new(29..99)
      # )
      # expect(out.map(&:value)).to eq([1])

      # out = tree.search_overlap(
      #   RangeCmp.new(3..41)
      # )
      # expect(out.map(&:value)).to eq([0, 2, 4])

      # out = tree.search_overlap(
      #   RangeCmp.new(0..1)
      # )
      # expect(out.map(&:value)).to eq([3])

      # out = tree.search_overlap(
      #   RangeCmp.new(10..15)
      # )
      # expect(out.map(&:value)).to eq([4])

      # tree = BinaryIntervalTree::Debug.new
      # [
      #   20..36,
      #   29..99,
      #   3..41,
      #   0..1,
      #   10..15
      # ].each.with_index do |range, i|
      #   tree.push(RangeCmpRev.new(range), i)
      # end

      # skip("Work on reverse later")

      # out = tree.search_all_covers_slow(
      #   RangeCmpRev.new(20..36)
      # )
      # expect(out.map(&:value)).to eq([0])

      # out = tree.search_all_covers_slow(
      #   RangeCmpRev.new(29..99)
      # )
      # expect(out.map(&:value)).to eq([1])

      # out = tree.search_all_covers_slow(
      #   RangeCmpRev.new(3..41)
      # )
      # expect(out.map(&:value)).to eq([0, 2, 4])

      # out = tree.search_all_covers_slow(
      #   RangeCmpRev.new(0..1)
      # )
      # expect(out.map(&:value)).to eq([3])

      # out = tree.search_all_covers_slow(
      #   RangeCmpRev.new(10..15)
      # )
      # expect(out.map(&:value)).to eq([4])

      # puts "rev"
      # puts tree.count
    end

    it "doesn't find deleted nodes" do
      tree = BinaryIntervalTree.new

      tree.push(RangeCmp.new(1..1), "a")
      tree.push(RangeCmp.new(5..5), "not_match")
      tree.push(RangeCmp.new(11..11), "b")

      key = RangeCmp.new(0..3)
      out = tree.search_all_covers_slow(key)
      expect(out.count).to eq(1)
      expect(out.map(&:value)).to eq(["a"])

      out.each { |node| tree.delete(node.key) }

      out = tree.search_all_covers_slow(key)
      expect(out.count).to eq(0)
      expect(out.map(&:value)).to eq([])
    end

    it "Annotates correctly after a deletion (7 elements)" do
      ranges = [
        347..354,
        427..427,
        271..280,
        374..387,
        428..428,
        320..327,
        364..372,
      ]
      tree = BinaryIntervalTree::Debug.new
      ranges.each do |range|
        tree.push(RangeCmp.new(range), RangeCmp.new(range))
      end

      key = 347..354
      expect(tree.get_node_for_key(RangeCmp.new(key)).annotate).to eq(387)
      tree.delete(RangeCmp.new(427..427))
      expect(tree.get_node_for_key(RangeCmp.new(key)).annotate).to eq(372)
    end

    it "Annotates correctly after deletion (1 element)" do
  # 5936..5946 annotate: 6817
  #   R: 6813..6817 annotate: 6817
  #     R: ∅️
  #     L: ∅️
  #   L: 5912..5919 annotate: 5919
  #     R: ∅️
  #     L: ∅️

  # 5936..5946 annotate: 6817
  #   R: ∅️
  #   L: 5912..5919 annotate: 5919
  #     R: ∅️
  #     L: ∅️

# Deleting 6813..6817
    end

    it "deletion annotation example (3 elements)" do
      ranges = [11..11, 23..27, 10..10]
      tree = BinaryIntervalTree::Debug.new
      ranges.each do |range|
        tree.push(RangeCmp.new(range), RangeCmp.new(range))
      end

      key = RangeCmp.new(10..12)
      from_all = tree.search_all_covers_slow(key).map(&:value).sort
      from_optimized = tree.delete_engulf(key).sort

      expect(from_optimized).to eq(from_all)
    end

    it "integration case versus search all covers fails IRL" do
      tree = BinaryIntervalTree::Debug.new
      ranges = [
        692..696,
        783..793,
        1058..1058,
        824..852,
      ]
      ranges.each.with_index do |range|
        tree.push(RangeCmp.new(range), range)
      end

      tree.push(RangeCmp.new(940..996), 940..996)

      expect(tree.get_node_for_key(RangeCmp.new(783..793)).annotate).to eq(852)

      key = RangeCmp.new(1058..1059)
      tree.validate_engulf_logic!(key)
    end

    it "lots of annotations" do
      ranges = [26..34, 78..83, 87..92, 97..102, 107..118, 123..134, 139..145, 166..169, 181..251, 260..266, 271..280, 290..405, 424..432, 451..453, 457..459, 488..494, 499..502, 508..521, 525..548]
      ranges.shuffle!
      tree = BinaryIntervalTree::Debug.new
      ranges.each do |range|
        tree.push(RangeCmp.new(range), "lol")
      end

      tree.push(RangeCmp.new(498..503), "lol")
    end

    it "annotations" do
      # Build a print function
      # print before and after rotation
      # https://tildesites.bowdoin.edu/~ltoma/teaching/cs231/fall09/Lectures/10-augmentedTrees/augtrees.pdf
      # page 6

      tree = BinaryIntervalTree::Debug.new

      i = 0
      tree.push(RangeCmp.new(29..99), i += 1)
      tree.push(RangeCmp.new(10..15), i += 1)
      tree.push(RangeCmp.new(3..41), i += 1)
      tree.push(RangeCmp.new(20..36), i += 1)
      tree.push(RangeCmp.new(0..1), i += 1)

      out = tree.get_node_for_key(
        RangeCmp.new(29..99)
      )
      expect(out.annotate).to eq(99)

      out = tree.get_node_for_key(
        RangeCmp.new(20..36)
      )
      expect(out.annotate).to eq(36)

      out = tree.get_node_for_key(
        RangeCmp.new(3..41)
      )
      expect(out.annotate).to eq(41)

      out = tree.get_node_for_key(
        RangeCmp.new(0..1)
      )
      expect(out.annotate).to eq(1)

      out = tree.get_node_for_key(
        RangeCmp.new(10..15)
      )
      expect(out.annotate).to eq(99)
    end

    # it "reverse annotations" do
    #   skip
    #   tree = BinaryIntervalTree.new
    #   [
    #     20..36,
    #     29..99,
    #     3..41,
    #     0..1,
    #     10..15
    #   ].each.with_index do |range, i|
    #     tree.push(RangeCmpRev.new(range), i)
    #   end

    #   out = tree.get_node_for_key(
    #     RangeCmpRev.new(29..99)
    #   )
    #   expect(out.annotate).to eq(29)

    #   out = tree.get_node_for_key(
    #     RangeCmpRev.new(3..41)
    #   )
    #   expect(out.annotate).to eq(29)

    #   # out = tree.get_node_for_key(
    #   #   RangeCmpRev.new(0..1)
    #   # )
    #   # expect(out.annotate).to eq(0)

    #   # out = tree.get_node_for_key(
    #   #   RangeCmpRev.new(20..36)
    #   # )
    #   # expect(out.annotate).to eq(20)

    #   out = tree.get_node_for_key(
    #     RangeCmpRev.new(10..15)
    #   )
    #   expect(out.annotate).to eq(20)
    # end
  end
end
