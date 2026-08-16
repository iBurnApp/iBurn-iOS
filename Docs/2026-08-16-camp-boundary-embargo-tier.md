# 2026-08-16 — Camp boundary map layer moves to the gates-open embargo tier

## High-Level Plan

**Problem.** The `camp-boundaries` style layer was gated on
`BRCEmbargo.canShowCampLocations()` — the *camp* tier, which for 2026 unlocks at
`CampLocationUnlock = 2026-08-23 00:01 PDT`, the Sunday one week before gates. The
boundary polygons are BMorg placement geometry and must stay hidden until gates open
(`EventStart = 2026-08-30`), the same tier art locations use.

**Fix.** Split the single `embargoAllowsCamps` input of
`CampLayerVisibility.resolve(...)` into two:

- `embargoAllowsBoundaries` ← `BRCEmbargo.canShowArtLocations()` — drives
  `camp-boundaries`.
- `embargoAllowsCamps` ← `BRCEmbargo.canShowCampLocations()` — still drives
  `camp-labels-big`, since a camp name at its placement centroid *is* camp-location
  data and is legitimately released a week early.

Both are still `&&`-ed with the user settings, so the settings toggles can only ever
subtract visibility.

## Technical Details

### `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/MapLayerManager.swift`

```swift
static func resolve(showCampBoundaries: Bool,
                    showCampBoundariesAlways: Bool,
                    showBigCampNames: Bool,
                    embargoAllowsBoundaries: Bool,
                    embargoAllowsCamps: Bool,
                    zoomLevel: Double) -> CampLayerVisibility {
    let boundariesVisible = showCampBoundaries && embargoAllowsBoundaries
    let labelsVisible = showBigCampNames && embargoAllowsCamps
    ...
}

static func current(zoomLevel: Double) -> CampLayerVisibility {
    resolve(showCampBoundaries: UserSettings.showCampBoundaries,
            showCampBoundariesAlways: UserSettings.showCampBoundariesAlways,
            showBigCampNames: UserSettings.showBigCampNames,
            embargoAllowsBoundaries: BRCEmbargo.canShowArtLocations(),
            embargoAllowsCamps: BRCEmbargo.canShowCampLocations(),
            zoomLevel: zoomLevel)
}
```

`current(zoomLevel:)` is the single entry point for both consumers
(`MapLayerManager` for the style layers, `MapViewAdapter` for the pin labels), so no
other call site needed changing. `BaseMapViewController` already re-resolves on
embargo unlock, which now covers the art-tier transition too.

### `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurnTests/EmbargoTierTests.swift`

- `makeCampLayers(...)` gained an `embargoAllowsBoundaries` parameter (defaults to
  `true`, matching the existing "unlocked" default).
- `testCampLayersHiddenWhileEmbargoedRegardlessOfSettings` now passes both flags
  `false`.
- New `testBoundariesStayHiddenAfterCampUnlockUntilGatesOpen` — pure-resolve check of
  the week between camp unlock and gates: labels draw, boundaries do not.
- New `testCurrentBoundaryVisibilityTracksTheArtTier` — end-to-end through
  `CampLayerVisibility.current`, time-travelling to `2026-08-25` (camps unlocked, art
  not → boundaries hidden) and `2026-08-31` (gates open → boundaries visible). Saves
  and restores `UserSettings.showCampBoundaries` / `showBigCampNames`.

The suite's `setUpWithError` sets `enteredBurningManRegion = true`, so the strict
rule (a date alone never unlocks) is satisfied and these cases exercise the tier dates
only — the strict half stays in `EmbargoStrictUnlockTests`.

## Commands

```bash
xcodebuild test -workspace iBurn.xcworkspace -scheme iBurnTests \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.5,arch=arm64' \
  -only-testing:iBurnTests/EmbargoTierTests 2>&1 | xcsift -f toon -w
# passed_tests: 48, failures: 0
```

Note: package resolution needs network, so this run required the sandbox disabled.

## Expected Outcomes

- Between 2026-08-23 and 2026-08-30, camp names may draw at their centroids but no
  camp boundary polygons appear, regardless of the map filter toggles.
- At `EventStart` (or on passcode unlock / in-region + date), boundaries appear and
  follow the "Zoomed" / "Always" settings as before.

## Cross-References

- `Docs/2026-08-06-placement-data-embargo-and-passcode.md` — the two-tier embargo
  design and passcode flow.
- `Docs/2025-08-23-camp-layer-implementation.md` — original camp boundary layer.

---

# Session 2 (2026-08-16): Search-as-you-type lag fix

## High-Level Plan

User bug report: "Searching got really laggy as I typed. After the first two
letters, I had to wait a few seconds for the third letter to even appear.
Working smoother now, but deleting characters gets laggy sometimes. Sometimes
it works smoothly for a while."

Root-cause analysis (Sonnet explore → two parallel Opus implementation agents →
Opus verification agent, orchestrated from the main session):

1. **FTS had no prefix matching** — `matching(searchText:)` used
   `FTS5Pattern(matchingAllTokensIn:)` (exact tokens, no `*`), so 2–5 letter
   partial words matched *nothing* and the keystroke completing a word dumped
   the entire result set in one frame. This was the whole user-visible
   all-or-nothing behavior, and it concentrated cause #2 into one stall.
   Deleting back across a word boundary did the same in reverse.
2. **Bursty synchronous thumbnail I/O on the main thread** — each new result
   row's `RowAssetsLoader` (one per `ObjectRowView`, `@MainActor`) did
   `UIImage(contentsOfFile:)` in `init` on NSCache miss. Warm caches explain
   the "smooth for a while" intermittency.
3. **Main-thread sort/dedup** of full result sets in
   `GlobalSearchViewModel.fetchResults` (`localizedStandardCompare`,
   per-occurrence Calendar math), plus sequential per-type fetches.
4. **A–Z index rail recomputed O(n) stops twice per SwiftUI render**
   (`SearchResultIndex.isEnabled`/`entries` each re-derived `stops(for:)`,
   incl. a `DateFormatter` per event row).

## Technical Details

### PlayaDB (Packages/PlayaDB)

- `QueryInterfaceRequest+DataObject.swift:139-172` — `matching(searchText:)`
  now builds `FTS5Pattern(matchingAllPrefixesIn:)` (`temp* gard*`). All-tokens-
  prefix (not last-token-only) because users abbreviate earlier words too
  ("cent cam" → Center Camp). Porter stemming composes fine with prefixes: a
  word-prefix is also a stem-prefix (verified by test).
- `PlayaDBImpl.swift` — new migration `v7-fts-prefix-index` drops `*_fts`
  tables whose DDL lacks `prefix=`; `setupFTS5Tables` recreates with
  `prefix='2 3 4'` and runs an FTS `rebuild` when it created the table.
  1-char prefixes deliberately skipped.
- Correction: the prefix *index* is purely a perf win — FTS5 answers `des*`
  on any table via term-dictionary scan; the missing `*` in the pattern was
  the entire correctness bug.
- New `FTSPrefixSearchTests.swift` (prefix hits, multi-word AND, stemming,
  legacy-schema migration rebuild). 330/330 package tests pass.

### App target (iBurn/ListView)

- `RowAssetsLoader.swift` — `init` now only does synchronous NSCache lookups
  (warm path unchanged, no flicker); disk stat + JPEG decode moved to
  `Task.detached` with `preparingForDisplay()`; new process-lifetime negative
  cache for media-free rows (note: a thumbnail downloaded mid-session won't
  appear in an already-checked row until restart — acceptable, possible
  follow-up: clear `missingAssetCache` on download-complete notification).
- `GlobalSearchViewModel.swift` — `fetchResults` is `nonisolated static`,
  four per-type fetches run via `async let`; sort/dedup/stops built off-main;
  cancellation preserved (child of `searchTask`, `checkCancellation` +
  pre-assignment `Task.isCancelled` guard). New `@Published indexStops` /
  `totalResultRows` memoize the rail.
- `SearchResultIndex.swift` — prebuilt-stops overloads; old overloads are thin
  wrappers; double `stops(for:)` pass eliminated.
- `GlobalSearchView.swift` — rail + inset read the memoized stops.
- New tests in `GlobalSearchFilterTests` / `GlobalSearchViewModelTests`.

### Verification (all PASS)

- PlayaDB 330/330; full `iBurnTests` 601/601 (iPhone 17 Pro Max, iOS 26.5).
- Seed zips regenerated (`playa-seed --fetch-media`): 2.1 MB → 3.1 MB (the
  prefix index), DDL carries `prefix='2 3 4'`, last migration
  `v7-fts-prefix-index`. Seeds are gitignored — CI/other machines must regen.
- Sim smoke test on a fresh install (deleted on-device DB): seed restored in
  0.8 s; "Te"→"Temple" typed incrementally with live results at every length;
  backspace to 2 chars stays responsive; scope switch re-runs query. No hang
  log entries.
- Known cosmetic follow-up: prefix search matches indexed *description* text,
  so "Te" surfaces rows matching e.g. "terrestrial" — pre-existing column
  config, now more visible. Consider ranking name matches above description
  matches later.

## Data pipeline status (same session)

- Camp GPS from the official placement layer: **already implemented Aug 9**
  (`apply_placement.js` precedence: polygon centroid → address geocoder →
  entrance centroid; 1184/1191 camps have polygon-centroid GPS from
  `data/2026/placement/public_camps.geojson`). `~/Downloads/placement_geojson`
  is stale 2025 QGIS data — do not import.
- Last API refresh was Aug 11; refreshing again this session
  (fetch_and_geocode → generate_all → apply_placement → seed regen), private
  submodule remote only (embargo: labels unlock Aug 23, boundaries/art Aug 30).
