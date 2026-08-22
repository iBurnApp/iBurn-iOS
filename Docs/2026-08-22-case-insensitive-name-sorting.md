# 2026-08-22 — Case-insensitive name sorting for browse lists

## High-Level Plan

**Problem.** The Art, Camps, and Mutant Vehicles lists sorted case-sensitively: every
capitalized name came first, then every lowercase one ("Zebra" before "apple"). Users
reading an alphabetical list see this as two interleaved alphabets.

**Root cause.** `orderedByName()` emitted `ORDER BY name ASC`, which SQLite resolves with
the default BINARY collation — a UTF-8 code-point comparison, where `A`–`Z` (0x41–0x5A)
all precede `a`–`z` (0x61–0x7A). `PlayaDBImpl.artRequest` / `campRequest` /
`mutantVehicleRequest` all end in `orderedByName()` and feed the SwiftUI lists with no
further sorting.

**Fix.** Collate with GRDB's built-in `localizedStandardCompare` — the Finder-style
comparison: case- and diacritic-insensitive, and numeric-aware so "Camp 2" precedes
"Camp 10". This matches `GlobalSearchViewModel.sortedByName`
(`iBurn/ListView/GlobalSearchViewModel.swift:383-391`), so browse lists and search
results now agree. A secondary `uid ASC` keeps equal-comparing names stably ordered.

## Technical Details

### `Packages/PlayaDB/Sources/PlayaDB/QueryExtensions/QueryInterfaceRequest+DataObject.swift`

```swift
public func orderedByName() -> Self {
    order(
        Self.columns.name.collating(.localizedStandardCompare).asc,
        Self.columns.uid.asc
    )
}
```

Collation availability was verified against the vendored GRDB: `DatabaseCollation`
declares `localizedStandardCompare`
(`GRDB/Core/Support/StandardLibrary/StandardLibrary.swift:926`) and `Database.setUp`
registers it on **every** connection GRDB opens (`GRDB/Core/Database.swift:597`). That
matters because the shipped DB is restored from the pre-baked `PlayaDB-<year>.zip` seed —
collations are per-connection, not stored in the file, so a seeded DB sorts correctly too.

Trade-off: the `name` indexes are BINARY-collated and cannot serve this ORDER BY, so
SQLite sorts in memory. Result sets are a few thousand rows; nothing in `QueryPlanTests`
asserted an index for this ORDER BY (its only index assertions are on
`event_occurrences`), and the full suite still passes.

### `Packages/PlayaDB/Sources/PlayaDB/PlayaDBImpl.swift`

The unfiltered `fetchArt()`, `fetchCamps()`, and `fetchMutantVehicles()` were returning
`X.fetchAll(db)` in arbitrary rowid order. They now route through `orderedByName()` so the
whole API is consistently ordered. (Their only app caller is `iBurnWatch/BrowseScreen.swift`,
which already re-sorts in memory at `iBurnWatch/ObjectListScreen.swift:97` — that stays,
harmlessly redundant.)

### Consistency fixes in the app target

- `iBurn/BRCDataSorter.swift:91-92` — `camps.sort { $0.title < $1.title }` →
  `localizedStandardCompare($1.title) == .orderedAscending` (same for `art`).
- `iBurn/UserMapViewAdapter.swift:78` — user-pin annotation titles, same change.

### Skipped: `iBurn/BRCDatabaseManager.m`

`+sorting` (line ~609/615) still uses `[data1.title compare:data2.title]`. It is the shared
sort block for several Yap views registered with hardcoded version tags (`@"7"` at line
630, `@"2"` at line 299, `@"7"` at line 480). Changing a Yap view's sort block requires
bumping every one of those tags to force a re-sort, which triggers a full view rebuild on
upgrade. Given Yap's default surfaces are already retired (only bridges/boot-import remain
on Yap), the churn is not worth it. Left as-is deliberately.

## Tests

New `Packages/PlayaDB/Tests/PlayaDBTests/NameOrderingTests.swift` inserts
`["cherry", "Zebra", "apple", "Banana"]` — an order whose BINARY sort
(`Banana, Zebra, apple, cherry`) differs from the expected `apple, Banana, cherry, Zebra` —
and asserts the expected order for:

- `fetchArt()`, `fetchCamps()`, `fetchMutantVehicles()`
- `fetchArt(filter:)`, `fetchCamps(filter:)`, `fetchMutantVehicles(filter:)` (what the
  SwiftUI lists actually observe)
- numeric awareness: `["Camp 10", "Camp 2", "camp 1"]` → `camp 1, Camp 2, Camp 10`
- the `uid` tiebreaker for identical names

## Expected Outcomes

- `swift test --package-path Packages/PlayaDB` → 345 passed, 0 failed.
- `xcodebuild -scheme iBurn` → success; `xcodebuild -scheme iBurnWatch` → success.
- Art / Camps / Mutant Vehicles browse lists read as a single alphabet, matching search.
