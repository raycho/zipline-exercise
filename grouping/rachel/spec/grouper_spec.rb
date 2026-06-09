# frozen_string_literal: true

require "spec_helper"
require "csv"
require "tempfile"

RSpec.describe Grouper do
  # ── helpers ────────────────────────────────────────────────────────────────

  # Build an in-memory CSV::Row array from a header array + array of value arrays.
  def make_rows(headers, *value_arrays)
    value_arrays.map { |vals| CSV::Row.new(headers, vals) }
  end

  # Convenience: call group and return just the ids (1-based integers).
  def ids_for(rows, match)
    Grouper.group(rows, match)
  end

  # ── normalize_phone ────────────────────────────────────────────────────────

  describe ".normalize_phone" do
    it "strips punctuation" do
      expect(Grouper.normalize_phone("(555) 123-4567")).to eq("5551234567")
    end

    it "strips dots" do
      expect(Grouper.normalize_phone("555.123.4567")).to eq("5551234567")
    end

    it "drops a leading country code of 1 for 11-digit numbers" do
      expect(Grouper.normalize_phone("15551234567")).to eq("5551234567")
    end

    it "does not drop leading 1 from 10-digit numbers" do
      expect(Grouper.normalize_phone("1234567890")).to eq("1234567890")
    end

    it "returns nil for blank input" do
      expect(Grouper.normalize_phone("")).to be_nil
      expect(Grouper.normalize_phone(nil)).to be_nil
    end
  end

  # ── same_email ─────────────────────────────────────────────────────────────

  describe ".group with :same_email" do
    let(:headers) { %w[FirstName Email] }

    it "groups rows that share an email" do
      rows = make_rows(headers,
        ["Alice", "alice@example.com"],
        ["Bob",   "bob@example.com"],
        ["Carol", "alice@example.com"])
      result = ids_for(rows, :same_email)
      expect(result[0]).to eq(result[2])   # Alice & Carol share email
      expect(result[1]).not_to eq(result[0])
    end

    it "treats email matching as case-insensitive" do
      rows = make_rows(headers,
        ["Alice", "Alice@Example.COM"],
        ["Bob",   "alice@example.com"])
      result = ids_for(rows, :same_email)
      expect(result[0]).to eq(result[1])
    end

    it "does not group rows that share only a phone" do
      hdrs = %w[FirstName Email Phone]
      rows = make_rows(hdrs,
        ["Alice", "alice@example.com", "5551234567"],
        ["Bob",   "bob@example.com",   "5551234567"])
      result = ids_for(rows, :same_email)
      expect(result[0]).not_to eq(result[1])
    end

    it "handles rows with blank emails independently" do
      rows = make_rows(headers,
        ["Alice", ""],
        ["Bob",   ""],
        ["Carol", "carol@example.com"])
      result = ids_for(rows, :same_email)
      # Two blank emails must NOT be merged
      expect(result[0]).not_to eq(result[1])
    end
  end

  # ── same_phone ─────────────────────────────────────────────────────────────

  describe ".group with :same_phone" do
    let(:headers) { %w[FirstName Phone] }

    it "groups rows that share a phone number" do
      rows = make_rows(headers,
        ["Alice", "(555) 123-4567"],
        ["Bob",   "555.123.4567"],
        ["Carol", "5559999999"])
      result = ids_for(rows, :same_phone)
      expect(result[0]).to eq(result[1])
      expect(result[2]).not_to eq(result[0])
    end

    it "normalises phone numbers across formats" do
      rows = make_rows(headers,
        ["Alice", "1-555-123-4567"],
        ["Bob",   "(555) 123-4567"])
      result = ids_for(rows, :same_phone)
      expect(result[0]).to eq(result[1])
    end

    it "does not group rows sharing only an email" do
      hdrs = %w[FirstName Email Phone]
      rows = make_rows(hdrs,
        ["Alice", "shared@example.com", "5551111111"],
        ["Bob",   "shared@example.com", "5552222222"])
      result = ids_for(rows, :same_phone)
      expect(result[0]).not_to eq(result[1])
    end

    it "handles multi-phone columns (Phone1, Phone2)" do
      hdrs = %w[FirstName Phone1 Phone2]
      rows = make_rows(hdrs,
        ["Alice", "5551234567", ""],
        ["Bob",   "5559999999", "5551234567"])
      result = ids_for(rows, :same_phone)
      expect(result[0]).to eq(result[1])  # Bob's Phone2 matches Alice's Phone1
    end
  end

  # ── same_email_or_phone ────────────────────────────────────────────────────

  describe ".group with :same_email_or_phone" do
    it "groups rows sharing an email" do
      hdrs  = %w[FirstName Email Phone]
      rows  = make_rows(hdrs,
        ["Alice", "shared@example.com", "5550000001"],
        ["Bob",   "shared@example.com", "5550000002"])
      result = ids_for(rows, :same_email_or_phone)
      expect(result[0]).to eq(result[1])
    end

    it "groups rows sharing a phone" do
      hdrs  = %w[FirstName Email Phone]
      rows  = make_rows(hdrs,
        ["Alice", "alice@example.com", "5551234567"],
        ["Bob",   "bob@example.com",   "5551234567"])
      result = ids_for(rows, :same_email_or_phone)
      expect(result[0]).to eq(result[1])
    end

    it "propagates groups transitively" do
      # A shares email with B; B shares phone with C → all three are one group
      hdrs  = %w[FirstName Email Phone]
      rows  = make_rows(hdrs,
        ["A", "shared@example.com", "5550000001"],
        ["B", "shared@example.com", "5551234567"],
        ["C", "c@example.com",      "5551234567"])
      result = ids_for(rows, :same_email_or_phone)
      expect(result[0]).to eq(result[1])
      expect(result[1]).to eq(result[2])
    end

    it "keeps truly separate people in different groups" do
      hdrs  = %w[FirstName Email Phone]
      rows  = make_rows(hdrs,
        ["Alice", "alice@example.com", "5550000001"],
        ["Bob",   "bob@example.com",   "5550000002"])
      result = ids_for(rows, :same_email_or_phone)
      expect(result[0]).not_to eq(result[1])
    end
  end

  # ── group id stability ─────────────────────────────────────────────────────

  describe "group id assignment" do
    it "assigns ids in row order starting at 1" do
      hdrs = %w[FirstName Email]
      rows = make_rows(hdrs,
        ["Alice", "alice@example.com"],
        ["Bob",   "bob@example.com"],
        ["Carol", "alice@example.com"])
      result = ids_for(rows, :same_email)
      # First seen group is 1, second seen group is 2
      expect(result[0]).to eq(1)
      expect(result[1]).to eq(2)
      expect(result[2]).to eq(1)
    end
  end

  # ── process (integration) ──────────────────────────────────────────────────

  describe ".process" do
    let(:csv_content) do
      <<~CSV
        FirstName,LastName,Email,Phone
        John,Smith,john@example.com,(555) 111-2222
        Jane,Doe,jane@example.com,(555) 111-2222
        Jack,Black,john@example.com,(555) 999-8888
      CSV
    end

    around do |example|
      Tempfile.create(["input", ".csv"]) do |f|
        f.write(csv_content)
        f.flush
        @path = f.path
        example.run
      end
    end

    it "prepends an id column to the output" do
      output = Grouper.process(@path, :same_email)
      rows   = CSV.parse(output, headers: true)
      expect(rows.headers.first).to eq("id")
    end

    it "preserves all original columns" do
      output  = Grouper.process(@path, :same_email)
      rows    = CSV.parse(output, headers: true)
      expect(rows.headers).to include("FirstName", "LastName", "Email", "Phone")
    end

    it "produces correct grouping for same_email" do
      output = Grouper.process(@path, :same_email)
      rows   = CSV.parse(output, headers: true)
      # John (row 0) and Jack (row 2) share john@example.com
      expect(rows[0]["id"]).to eq(rows[2]["id"])
      expect(rows[0]["id"]).not_to eq(rows[1]["id"])
    end

    it "produces correct grouping for same_phone" do
      output = Grouper.process(@path, :same_phone)
      rows   = CSV.parse(output, headers: true)
      # John (row 0) and Jane (row 1) share (555) 111-2222
      expect(rows[0]["id"]).to eq(rows[1]["id"])
      expect(rows[0]["id"]).not_to eq(rows[2]["id"])
    end

    it "merges groups transitively for same_email_or_phone" do
      output = Grouper.process(@path, :same_email_or_phone)
      rows   = CSV.parse(output, headers: true)
      # John matches Jane via phone; John matches Jack via email → all three in one group
      expect(rows[0]["id"]).to eq(rows[1]["id"])
      expect(rows[0]["id"]).to eq(rows[2]["id"])
    end
  end

  # ── real input files ───────────────────────────────────────────────────────

  describe "real input files" do
    let(:fixture_dir) { File.expand_path("../../", __FILE__) }

    %w[input1.csv input2.csv].each do |filename|
      context filename do
        let(:path) { File.join(fixture_dir, filename) }

        %i[same_email same_phone same_email_or_phone].each do |match|
          it "processes with #{match} without error" do
            output = Grouper.process(path, match)
            rows   = CSV.parse(output, headers: true)
            expect(rows.headers.first).to eq("id")
            expect(rows.count).to be > 0
          end
        end
      end
    end
  end
end
