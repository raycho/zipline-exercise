# frozen_string_literal: true

module Grouper
  # Disjoint-set / union-find with path compression and union by rank.
  #
  # Elements are added one at a time via #add, which returns the new index.
  # This allows streaming use where the total row count is not known upfront.
  class UnionFind
    def initialize
      @parent = []
      @rank   = []
    end

    # Register a new element and return its index.
    def add
      i = @parent.size
      @parent << i
      @rank   << 0
      i
    end

    def size
      @parent.size
    end

    def find(x)
      @parent[x] = find(@parent[x]) unless @parent[x] == x
      @parent[x]
    end

    def union(x, y)
      rx, ry = find(x), find(y)
      return if rx == ry

      if @rank[rx] < @rank[ry]
        @parent[rx] = ry
      elsif @rank[rx] > @rank[ry]
        @parent[ry] = rx
      else
        @parent[ry] = rx
        @rank[rx] += 1
      end
    end
  end
end
