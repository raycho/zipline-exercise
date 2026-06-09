# frozen_string_literal: true

require "csv"
require_relative "union_find"

module Grouper
  # Strip everything that isn't a digit, then drop a leading country code of "1"
  # so that (555) 123-4567, 15551234567, and 555-123-4567 all normalise to
  # "5551234567".
  def self.normalize_phone(raw)
    digits = raw.to_s.gsub(/\D/, "")
    digits = digits[1..] if digits.length == 11 && digits.start_with?("1")
    digits.empty? ? nil : digits
  end

  # Return every column header whose downcased name contains *token*.
  def self.columns_matching(headers, token)
    headers.select { |h| h.to_s.downcase.include?(token) }
  end

  # Peek at the first 4 KB of the file to detect the line-ending style.
  # input1.csv uses bare CR (old Mac format), so we cannot assume "\n".
  def self.detect_row_sep(path)
    sample = File.read(path, 4096) || ""
    if sample.include?("\r\n")
      "\r\n"
    elsif sample.include?("\r")
      "\r"
    else
      "\n"
    end
  end

  # Pass 1 – stream the CSV and build a fully resolved UnionFind.
  #
  # Rows are never stored; only the two integer arrays inside UnionFind
  # and the email/phone index hashes are kept in memory.
  #
  # @param input_path  [String]  path to the input CSV
  # @param match       [Symbol]  :same_email | :same_phone | :same_email_or_phone
  # @param row_sep     [String]  line-ending character(s) for the CSV parser
  # @return [Array(UnionFind, Array<String>, Array<Integer>)]
  #         the populated UnionFind, the original headers, and the resolved
  #         group-id array (1-based, stable, one entry per data row)
  def self.build_union_find(input_path, match, row_sep)
    uf           = UnionFind.new
    email_index  = {}
    phone_index  = {}
    headers      = nil
    email_cols   = []
    phone_cols   = []

    CSV.foreach(input_path, headers: true, row_sep: row_sep) do |row|
      if headers.nil?
        headers    = row.headers
        email_cols = columns_matching(headers, "email")
        phone_cols = columns_matching(headers, "phone")
      end

      i = uf.add

      if %i[same_email same_email_or_phone].include?(match)
        email_cols.each do |col|
          val = row[col].to_s.strip.downcase
          next if val.empty?

          if email_index.key?(val)
            uf.union(i, email_index[val])
          else
            email_index[val] = i
          end
        end
      end

      if %i[same_phone same_email_or_phone].include?(match)
        phone_cols.each do |col|
          val = normalize_phone(row[col])
          next if val.nil?

          if phone_index.key?(val)
            uf.union(i, phone_index[val])
          else
            phone_index[val] = i
          end
        end
      end
    end

    # Resolve stable group ids now so pass 2 is a plain array lookup.
    group_id = {}
    next_id  = 1
    ids = Array.new(uf.size) do |i|
      root = uf.find(i)
      group_id[root] ||= next_id.tap { next_id += 1 }
      group_id[root]
    end

    [uf, headers || [], ids]
  end

  # Core grouping logic (used by tests and process).
  #
  # @param rows   [Array<CSV::Row>]  parsed rows
  # @param match  [Symbol]           :same_email | :same_phone | :same_email_or_phone
  # @return       [Array<Integer>]   group id for each row (stable, 1-based)
  def self.group(rows, match)
    return [] if rows.empty?

    headers    = rows.first.headers
    email_cols = columns_matching(headers, "email")
    phone_cols = columns_matching(headers, "phone")
    uf         = UnionFind.new

    rows.each_with_index do |row, i|
      uf.add

      if %i[same_email same_email_or_phone].include?(match)
        email_index = defined?(email_index) ? email_index : {}
        email_cols.each do |col|
          val = row[col].to_s.strip.downcase
          next if val.empty?
          email_index.key?(val) ? uf.union(i, email_index[val]) : email_index[val] = i
        end
      end

      if %i[same_phone same_email_or_phone].include?(match)
        phone_index = defined?(phone_index) ? phone_index : {}
        phone_cols.each do |col|
          val = normalize_phone(row[col])
          next if val.nil?
          phone_index.key?(val) ? uf.union(i, phone_index[val]) : phone_index[val] = i
        end
      end
    end

    group_id = {}
    next_id  = 1
    rows.each_index.map do |i|
      root = uf.find(i)
      group_id[root] ||= next_id.tap { next_id += 1 }
      group_id[root]
    end
  end

  # Process a CSV file and return the output as a String.
  #
  # Uses a two-pass streaming approach so only two integer arrays (parent +
  # rank, ~16 bytes per row) and the lookup index hashes are held in memory
  # during pass 1. Pass 2 streams the file a second time and builds the
  # output line-by-line rather than materialising all rows at once.
  #
  # @param input_path  [String]  path to the input CSV
  # @param match       [Symbol]  matching strategy
  # @return            [String]  CSV text with "id" column prepended
  def self.process(input_path, match)
    row_sep = detect_row_sep(input_path)
    _uf, headers, ids = build_union_find(input_path, match, row_sep)

    # Pass 2 – stream the file again, prepend the resolved id, emit output.
    i = 0
    CSV.generate do |out|
      out << ["id"] + headers
      CSV.foreach(input_path, headers: true, row_sep: row_sep) do |row|
        out << [ids[i]] + row.fields
        i += 1
      end
    end
  end
end
