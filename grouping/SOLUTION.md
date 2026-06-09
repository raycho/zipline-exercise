# Grouper — Solution

A Ruby CLI that reads a CSV file and assigns each row a group ID based on a configurable matching strategy.

## Usage

```bash
ruby grouper.rb <input.csv> <matching_type>
```

`matching_type` must be one of:

| Value | Behaviour |
|---|---|
| `same_email` | Rows that share any email address column |
| `same_phone` | Rows that share any phone number column (after normalisation) |
| `same_email_or_phone` | Either of the above |

### Examples

```bash
ruby grouper.rb input1.csv same_email
ruby grouper.rb input2.csv same_phone
ruby grouper.rb input3.csv same_email_or_phone
```

Output is written to stdout — redirect it to save:

```bash
ruby grouper.rb input1.csv same_email_or_phone > output.csv
```

## Design

### Column detection

Rather than hard-coding column names, the library finds email and phone columns by matching substrings against the header names (case-insensitive). This means `Email`, `Email1`, `Email2`, `Phone`, `Phone1`, `Phone2`, etc. are all picked up automatically without any configuration.

### Phone normalisation

All non-digit characters are stripped, then a leading country-code `1` is removed from 11-digit numbers. This makes `(555) 123-4567`, `555.123.4567`, `15551234567`, and `1-555-123-4567` all compare as equal.

### Grouping algorithm (Union-Find)

Matching is transitive: if Alice shares an email with Bob, and Bob shares a phone with Carol, then Alice, Bob, and Carol are all the same person. A simple equality lookup would miss this.

The solution uses a **Union-Find (disjoint-set)** data structure with path compression and union-by-rank. As each row is processed, its email/phone values are looked up in an index. If the value has been seen before, the two row indices are unioned. At the end, every row's root is resolved and mapped to a stable, 1-based group ID assigned in row order.

This runs in near-linear time and handles any depth of transitivity correctly.

### Two-pass streaming

To keep memory usage practical at scale, `process` uses a two-pass streaming design:

- **Pass 1** — streams the file line-by-line with `CSV.foreach`, calling `uf.add` per row and updating the index hashes. Rows are never stored. At the end, group IDs are resolved from the UnionFind into a plain integer array.
- **Pass 2** — streams the file a second time, prepending the resolved group ID to each row as it is written to the output.

This keeps peak memory at ~16 bytes per row (two integers in the UnionFind) rather than materialising all `CSV::Row` objects at once. At 1 million rows this reduced peak RAM from ~1.3 GB to ~280–430 MB.

### File layout

```
grouper.rb          — CLI entry point
lib/
  grouper.rb        — core logic (Grouper module)
  union_find.rb     — UnionFind data structure (extracted to its own file)
spec/
  grouper_spec.rb   — RSpec test suite
  union_find_spec.rb — dedicated UnionFind unit tests
  spec_helper.rb
Gemfile             — rspec dependency
SOLUTION.md         — this file
```

## Running Tests

```bash
bundle install
bundle exec rspec
```

The spec suite covers:
- Phone normalisation edge cases
- All three matching strategies
- Transitive grouping
- Multi-column CSVs (Phone1/Phone2, Email1/Email2)
- Blank values not incorrectly merged
- End-to-end `process` integration
- All real input files (input1.csv, input2.csv)
- `UnionFind` in isolation: `#add`, `#find`, `#union`, `#size`, path compression, union-by-rank, group identity — covering positive, negative, and edge cases

## AI Usage

I used Claude (Cowork mode) for the majority of the implementation. Here is how the process went:

**What I prompted:** I asked Claude to read the README and build a complete Ruby application matching the spec, including library code, a CLI, and tests.

**What Claude got right immediately:**
- The Union-Find approach for transitive grouping — exactly the right algorithm
- Column auto-detection by substring matching headers
- Phone normalisation logic
- The overall file structure and CLI design

**Where I had to intervene / verify:**
- `CSV::Table#to_a` converts rows to plain arrays, losing the `CSV::Row` wrapper and its `#headers` method — Claude's first draft called `.to_a` on the table, which broke column detection. I identified this from the error and Claude fixed it.
- `input1.csv` uses bare CR (`\r`) line endings, not LF. The default CSV parser didn't split rows correctly. Claude added a `.gsub(/\r\n?/, "\n")` normalisation step once I pointed this out.
- I reviewed every method and test to make sure I understood and could explain the logic before accepting it.

The prompts I gave were: "read the README.md and build me a ruby application that fits the requirements" and then follow-up correction messages after observing the two bugs above.

## Session changes (post-initial implementation)

The following changes were made in a follow-up session:

### `UnionFind` extracted to its own file
`lib/union_find.rb` was created to hold the `Grouper::UnionFind` class. Previously it lived inline inside `lib/grouper.rb`. `lib/grouper.rb` now references it via `require_relative "union_find"`.

### `UnionFind` made dynamically sized
`UnionFind#initialize` no longer takes a `size` argument. A new `#add` method registers one element at a time and returns its index. This decouples the data structure from needing to know the row count upfront, which is a prerequisite for streaming.

### Two-pass streaming introduced
`Grouper.process` was rewritten to use two streaming passes rather than loading all rows into memory at once:
- `detect_row_sep` peeks at the first 4 KB to identify line endings, replacing the old `File.read(...).gsub` approach.
- `build_union_find` is a new method that performs pass 1: streams the CSV with `CSV.foreach`, calls `uf.add` per row, and resolves group IDs into a plain integer array — without ever storing a `CSV::Row`.
- Pass 2 streams the file again and writes each row with its prepended ID.

**Memory impact at 1 million rows:** peak RAM dropped from ~1.3 GB to ~280–430 MB (~70% reduction). Runtime was unchanged at ~9–12 seconds.

### Dedicated `UnionFind` test suite added
`spec/union_find_spec.rb` was created with full unit test coverage of `UnionFind` in isolation, including positive, negative, and edge cases for `#add`, `#find`, `#union`, `#size`, path compression, union-by-rank, and group identity.
