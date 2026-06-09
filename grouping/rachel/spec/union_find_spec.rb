# frozen_string_literal: true

require "spec_helper"
require "union_find"

RSpec.describe Grouper::UnionFind do
  # Helper: create a UnionFind and add n elements, returning the instance.
  def build(n)
    uf = described_class.new
    n.times { uf.add }
    uf
  end

  # ── initialization ─────────────────────────────────────────────────────────

  describe "#initialize" do
    it "starts empty with a size of zero" do
      uf = described_class.new
      expect(uf.size).to eq(0)
    end
  end

  # ── add ────────────────────────────────────────────────────────────────────

  describe "#add" do
    it "returns 0-based sequential indices" do
      uf = described_class.new
      expect(uf.add).to eq(0)
      expect(uf.add).to eq(1)
      expect(uf.add).to eq(2)
    end

    it "increments size by 1 each call" do
      uf = described_class.new
      3.times { |n| expect { uf.add }.to change(uf, :size).from(n).to(n + 1) }
    end

    it "makes the new element its own root" do
      uf = described_class.new
      i = uf.add
      expect(uf.find(i)).to eq(i)
    end
  end

  # ── find ───────────────────────────────────────────────────────────────────

  describe "#find" do
    # positive
    it "returns each element as its own root before any unions" do
      uf = build(4)
      (0..3).each { |i| expect(uf.find(i)).to eq(i) }
    end

    it "returns the same root for two elements after they are unioned" do
      uf = build(2)
      uf.union(0, 1)
      expect(uf.find(0)).to eq(uf.find(1))
    end

    it "returns a consistent root for all members after a chain of unions" do
      uf = build(4)
      uf.union(0, 1)
      uf.union(1, 2)
      uf.union(2, 3)
      root = uf.find(0)
      (1..3).each { |i| expect(uf.find(i)).to eq(root) }
    end

    # path compression
    it "applies path compression so every node resolves directly to the root" do
      uf = build(5)
      uf.union(0, 1)
      uf.union(1, 2)
      uf.union(2, 3)
      uf.union(3, 4)
      root = uf.find(4)
      (0..4).each { |i| expect(uf.find(i)).to eq(root) }
    end

    # negative
    it "returns different roots for elements in different groups" do
      uf = build(4)
      uf.union(0, 1)
      uf.union(2, 3)
      expect(uf.find(0)).not_to eq(uf.find(2))
    end

    # edge
    it "handles a single element without error" do
      uf = described_class.new
      uf.add
      expect { uf.find(0) }.not_to raise_error
      expect(uf.find(0)).to eq(0)
    end
  end

  # ── union ──────────────────────────────────────────────────────────────────

  describe "#union" do
    # positive
    it "merges two separate elements into the same group" do
      uf = build(2)
      uf.union(0, 1)
      expect(uf.find(0)).to eq(uf.find(1))
    end

    it "merges groups transitively (A–B then B–C unites A, B, C)" do
      uf = build(3)
      uf.union(0, 1)
      uf.union(1, 2)
      expect(uf.find(0)).to eq(uf.find(2))
    end

    it "merges multiple disjoint groups independently" do
      uf = build(6)
      uf.union(0, 1)
      uf.union(2, 3)
      uf.union(4, 5)
      expect(uf.find(0)).to eq(uf.find(1))
      expect(uf.find(2)).to eq(uf.find(3))
      expect(uf.find(4)).to eq(uf.find(5))
      expect(uf.find(0)).not_to eq(uf.find(2))
      expect(uf.find(0)).not_to eq(uf.find(4))
    end

    it "unites two existing groups when any member from each is passed" do
      uf = build(4)
      uf.union(0, 1) # group A: {0,1}
      uf.union(2, 3) # group B: {2,3}
      uf.union(1, 2) # merge via non-root members
      expect(uf.find(0)).to eq(uf.find(3))
    end

    # negative
    it "is idempotent – unioning an already-merged pair does not change the root" do
      uf = build(2)
      uf.union(0, 1)
      root_before = uf.find(0)
      uf.union(0, 1)
      expect(uf.find(0)).to eq(root_before)
    end

    it "does not merge elements outside the unioned pair" do
      uf = build(3)
      uf.union(0, 1)
      expect(uf.find(2)).not_to eq(uf.find(0))
    end

    it "unioning an element with itself leaves it as its own root" do
      uf = build(3)
      uf.union(1, 1)
      expect(uf.find(1)).to eq(1)
    end

    # union-by-rank
    it "attaches the lower-rank tree under the higher-rank root" do
      uf = build(3)
      uf.union(0, 1)
      root_after_first = uf.find(0)
      uf.union(root_after_first, 2)
      expect(uf.find(2)).to eq(root_after_first)
    end

    # edge
    it "works correctly when all elements are unioned in a forward chain" do
      n = 10
      uf = build(n)
      (0...n - 1).each { |i| uf.union(i, i + 1) }
      root = uf.find(0)
      (1...n).each { |i| expect(uf.find(i)).to eq(root) }
    end

    it "works correctly when all elements are unioned in reverse order" do
      n = 5
      uf = build(n)
      (n - 1).downto(1) { |i| uf.union(i, i - 1) }
      root = uf.find(0)
      (1...n).each { |i| expect(uf.find(i)).to eq(root) }
    end
  end

  # ── size ───────────────────────────────────────────────────────────────────

  describe "#size" do
    it "returns 0 for a new instance" do
      expect(described_class.new.size).to eq(0)
    end

    it "reflects the number of elements added" do
      uf = build(5)
      expect(uf.size).to eq(5)
    end

    it "is unaffected by union operations" do
      uf = build(4)
      uf.union(0, 1)
      uf.union(2, 3)
      expect(uf.size).to eq(4)
    end
  end

  # ── group identity ─────────────────────────────────────────────────────────

  describe "group identity" do
    it "n elements with no unions form n distinct groups" do
      uf = build(5)
      roots = (0...5).map { |i| uf.find(i) }
      expect(roots.uniq.size).to eq(5)
    end

    it "fully unioned structure collapses to a single group" do
      n = 6
      uf = build(n)
      (0...n - 1).each { |i| uf.union(0, i + 1) }
      roots = (0...n).map { |i| uf.find(i) }
      expect(roots.uniq.size).to eq(1)
    end

    it "partial unions produce the expected number of distinct groups" do
      uf = build(6)
      uf.union(0, 1) # group 1: {0,1}
      uf.union(2, 3) # group 2: {2,3}
                     # 4 and 5 remain singletons
      roots = (0...6).map { |i| uf.find(i) }
      expect(roots.uniq.size).to eq(4)
    end
  end
end
