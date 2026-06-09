# Grouper

A Ruby CLI that reads a CSV file and assigns each row a group ID based on a configurable matching strategy. Rows that share an email address, phone number, or both are considered the same person and receive the same ID. Matching is fully transitive — if Alice matches Bob via email, and Bob matches Carol via phone, all three are grouped together.

---

## Requirements

- Ruby (2.7+ recommended)
- Bundler

---

## Installation

```bash
bundle install
```

---

## Usage

```bash
ruby grouper.rb <input.csv> <matching_type>
```

### Matching types

| Value | Behaviour |
|---|---|
| `same_email` | Groups rows that share any email address column |
| `same_phone` | Groups rows that share any phone number column (after normalisation) |
| `same_email_or_phone` | Groups rows that share an email OR a phone number |

### Examples

```bash
ruby grouper.rb input1.csv same_email
ruby grouper.rb input2.csv same_phone
ruby grouper.rb input3.csv same_email_or_phone
```

### Saving output

Output is written to stdout. Redirect it to save to a file:

```bash
ruby grouper.rb input1.csv same_email_or_phone > output.csv
```

### Output format

The output is a copy of the original CSV with an `id` column prepended. Rows in the same group share the same ID. IDs are 1-based integers assigned in the order their group is first encountered.

```
id,FirstName,LastName,Email,Phone
1,John,Smith,john@example.com,(555) 111-2222
2,Jane,Doe,jane@example.com,(555) 333-4444
1,Jack,Black,john@example.com,(555) 999-8888
```

---

## Design

### Column detection

Email and phone columns are detected automatically by matching substrings against header names (case-insensitive). `Email`, `Email1`, `WorkEmail`, `Phone`, `Phone1`, `Phone2`, etc. are all picked up without any configuration.

### Phone normalisation

All non-digit characters are stripped, then a leading country-code `1` is removed from 11-digit numbers. This makes `(555) 123-4567`, `555.123.4567`, `15551234567`, and `1-555-123-4567` all compare as equal.

### Grouping algorithm — Union-Find

Simple equality lookups would miss transitive matches (Alice = Bob via email, Bob = Carol via phone → all three are the same person). The solution uses a **Union-Find (disjoint-set)** data structure with path compression and union-by-rank. As each row is processed, its email/phone values are looked up in an index. If a value has been seen before, the two rows are unioned. At the end every row's root is resolved into a stable group ID. This runs in near-linear time regardless of the depth of transitivity.

### Two-pass streaming

To keep memory usage practical at scale, processing uses two streaming passes:

- **Pass 1** — streams the file line-by-line, building the UnionFind and index hashes. Rows are never stored in memory.
- **Pass 2** — streams the file again and writes each row with its resolved group ID prepended.

At 1 million rows this keeps peak RAM at ~280–430 MB, compared to ~1.3 GB when all rows were materialised at once.

---

## File layout

```
grouper.rb              — CLI entry point (argument validation, calls Grouper.process)
lib/
  grouper.rb            — core logic: normalisation, column detection, streaming passes
  union_find.rb         — UnionFind data structure (dynamic, streaming-friendly)
spec/
  grouper_spec.rb       — RSpec tests for Grouper module
  union_find_spec.rb    — RSpec unit tests for UnionFind
  spec_helper.rb
Gemfile
rachel/
  README.md             — this file
  SOLUTION.md           — detailed design and change log
  RACHEL.md             — full prompt log across sessions
```

---

## Running tests

```bash
bundle install
bundle exec rspec
```

### Test coverage

- Phone normalisation edge cases
- All three matching strategies
- Transitive grouping
- Multi-column CSVs (`Phone1`/`Phone2`, `Email1`/`Email2`)
- Blank values not incorrectly merged
- End-to-end `process` integration against real input files
- `UnionFind` in isolation: `#add`, `#find`, `#union`, `#size`, path compression, union-by-rank, group identity — positive, negative, and edge cases

---

## Performance (1 million rows, 54 MB CSV)

| Match mode | Time | Peak RAM |
|---|---|---|
| `same_email` | ~9.4s | ~285 MB |
| `same_phone` | ~10.3s | ~273 MB |
| `same_email_or_phone` | ~11.7s | ~426 MB |

---

## AI Usage

Built using Claude (Cowork mode). Claude produced the initial implementation including the Union-Find algorithm, column auto-detection, phone normalisation, and test suite. Two bugs required manual intervention: a `CSV::Table#to_a` call that stripped the `CSV::Row` wrapper (breaking column detection), and bare CR line endings in `input1.csv` that the default CSV parser did not handle. Both were identified by running the code and observing the failures.

In a follow-up session, Claude was used to extract `UnionFind` into its own file, expand the test suite with full positive/negative/edge coverage, and rewrite `process` to use two-pass streaming — reducing peak memory by ~70% at 1 million rows.

See `RACHEL.md` for the complete prompt log and `SOLUTION.md` for the detailed change history.
