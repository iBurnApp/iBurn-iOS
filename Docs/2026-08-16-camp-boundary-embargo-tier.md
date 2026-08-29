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

### 2026 API refresh (Aug 16) — completed

Pipeline run exactly as documented in `Docs/2026-07-18-api-data-refresh.md` +
`Docs/2026-08-09-merge-and-2026-placement-data.md`:

1. `node src/cli/fetch_and_geocode.js --year 2026 …` (sandbox disabled;
   `api.burningman.org` is outside the allowlist). Succeeded on the first
   attempt — no `update.json` clobber to recover from this time.
   Geocoder: 1175/1187 camps placed from addresses; the 6 hard failures are the
   usual plaza/airport-road strings (Orphan Asylum, Nom De Plume, Bo_b Squad,
   Venice Red Light, Flybynyte, Black Rock Travel Agency).
2. `node src/cli/generate_all.js -d ../../data/2026` — no geo output changed
   (layout/GIS inputs untouched, as expected). Geocoder bundle rebuild skipped.
3. `node scripts/apply_placement.js --year 2026`.

**Counts (Aug 11 → Aug 16)**

| | before | after |
|---|---|---|
| camps | 1190 | 1187 |
| camps with GPS | 1183 | 1180 |
| camps with `location_string` | 1185 | 1182 |
| art | 331 | 334 |
| art with GPS | 331 | 334 |
| events (raw rows) | 2606 | 2635 |
| event occurrences (raw) | 5277 | 5316 |
| mutant vehicles | 495 | 494 |
| `camp_outlines`/`camp_labels` features | 1183 | 1178 |

5 duplicate event uids in the feed (2635 rows → 2630 unique), deduped at
import — down from 19 dupes on Aug 11.

**Placement re-apply notes.** 13 camps get outlines only from the direct
polygon export, 0 from the OCR fallback, 9 have no footprint at all, and 5
placement records no longer match any camp in the API roster (those 5 dropped
out of the geojson: 1183 → 1178). New this refresh: **16 fill-only conflicts**
where the API's own location fields now disagree with the drop (Swan Forest,
ta-keel-ya, Memento Mori, dimensions/exact_location wording on a few others).
The API value is kept in every case, which is the correct precedence — the API
is now the fresher source for text, the drop only contributes geometry. Aug 9
logged zero conflicts because the drop was built from that day's API snapshot.

**Seeds.** `swift run --package-path Packages/PlayaSeed playa-seed --fetch-media`
→ `iBurn/PlayaDB-2026.zip` + `iBurnWatch/PlayaDB-2026.zip` (2 × 3051 KB;
334 art / 1187 camps / 5311 occurrences / 494 MVs / 1580 thumbnail colours).
5 new thumbnails downloaded and committed into `MediaFiles.bundle`.

**Legacy Yap seed (`iBurn/iBurn-2026.zip`) is PENDING.** Part C of
`Docs/2026-07-18-api-data-refresh.md` is a manual simulator procedure (fresh
install → let the JSON import finish → zip the container's
`Application Support/iBurn/iBurn-2026` folder), with no scripted equivalent, so
it was not run here. The bundled zip is still the Aug 11 harvest; a first launch
on a build shipping today's JSON will restore that seed and then re-import,
which is correct but slow. Re-harvest before cutting the next build.

**Validation.** `swift test --package-path Packages/PlayaDB` → 330 passing,
0 failures. Ship guards clean (no `MOCK_LOCATIONS` sentinel, no 2025 fixture
markers in the generated geojson).

**Commits (local only — nothing pushed to any remote, `public` never contacted):**

- submodule `b8934c2` — 2026 API refresh (Aug 16) + placement re-applied
- submodule `4743806` — 2026 media: fetch 5 thumbnails new in the Aug 16 API data
- app `0b4295fe` — Bump iBurn-Data: 2026 API refresh (Aug 16)

---

# Session 3 (2026-08-16): Bulk camp placement moves to the gates tier

## High-Level Plan

**Policy (user decision).** Exact placement info — *anything that shows many camps'
positions at once* — waits for gates open (`YearSettings.eventStart`, 2026-08-30).
The Aug 23 camp tier (`YearSettings.campLocationUnlock`) keeps unlocking camp
**address text** and **single-camp pins** only. The passcode bypasses both, as before.

This supersedes Session 1 above, which left `camp-labels-big` on the camp tier: a camp
name drawn at its placement centroid *is* that camp's exact position, and the layer
draws the whole city at once.

**New seam.** `MapEmbargo` (in `iBurn/EmbargoService.swift`) names the choice so call
sites read as policy rather than as a tier lookup:

- `allowsBulkCampPlacement()` → gates tier (`.art`)
- `allowsSingleCampLocation()` → camp tier (`.camp`)
- `allowsArtLocation()` → gates tier
- `allowsBulkEventPin(locatedAtArt:)` → gates either way (spelled out, not collapsed)

## Tier per surface after this change

| Surface | Tier |
|---|---|
| `camp-labels-big` style layer (`CampLayerVisibility`) | **gates** (was camp) |
| `camp-boundaries` style layer | gates (Session 1) |
| Browse map camp pins (`PlayaDBAnnotationDataSource`) | **gates** (was camp) |
| Browse map active-event pins hosted at camps | **gates** (was camp) |
| Viewport region fetch (`UserMapViewAdapter.refreshRegionAnnotations`) | **gates** (was camp) |
| Map favourite camp / favourite camp-hosted event pins | camp (user-curated, unchanged) |
| Camp list "Show on Map" (`CampListHostingController`) | gates (already; comment added) |
| Single camp pin — detail map, pushed map, `DataObjectAnnotation` | camp |
| Camp address text (Nearby, detail, lists) | camp |
| Art, anywhere | gates |
| Nearby / Favorites / Recently Viewed / Visits / watch | camp (unchanged) |

## Technical Details

- `iBurn/EmbargoService.swift` — new `MapEmbargo` enum (bottom of file).
- `iBurn/MapLayerManager.swift` — `CampLayerVisibility.resolve` collapses
  `embargoAllowsBoundaries` + `embargoAllowsCamps` into one `embargoAllowsPlacement`;
  `current(zoomLevel:)` feeds it `MapEmbargo.allowsBulkCampPlacement()`.
  Consequence, and correct: pre-gates `campNamesDrawnByStyleLayer` is false, so the
  camp pins that *do* survive (favourites) label themselves instead of yielding to a
  layer that isn't painting. `MapViewAdapter.updatePinLabelVisibility()` and
  `campUID(forStyleLabelAt:)` read the same resolver and needed no change — the tap
  handler still refuses taps on stale tiles.
- `iBurn/PlayaDBAnnotationDataSource.swift` — `campBulkAllowed` (gates) drives the
  browse camp + active-event layers; new `campFavoriteAllowed` (camp tier) drives the
  favourites layers.
- `iBurn/UserMapViewAdapter.swift` — region fetch passes
  `campAllowed: MapEmbargo.allowsBulkCampPlacement()`; `MapRegionAnnotationFilter`
  itself is unchanged (tiers are still parameters).
- `iBurn/AnnotationDataSource.swift` — defense in depth:
  `BRCDataObject.annotation(metadata:)` now returns nil when
  `BRCEmbargo.canShowLocation(for:)` says no (it was the one ungated constructor), and
  new `AnnotationEmbargo.allows(_:)` filters `StaticAnnotationDataSource.allAnnotations()`
  — the last line before a coordinate reaches a map view, at the single-object tiers, so
  it subtracts nothing any caller legitimately shows.

## Judgment calls

1. **Map favourites stayed on the camp tier.** A favourites layer can hold many camps,
   but it is the hand-built subset the Favorites list shows, and the brief explicitly
   kept `FavoritesViewModel` on the camp tier. Flagged for a final call: one line
   (`campFavoriteAllowed`) flips it.
2. **Bulk event pins → gates.** A camp-hosted event pin sits on its host camp, so a
   viewport of them maps the camps. Single-event surfaces keep the camp tier via
   `BRCEmbargo.canShowLocation(for:)`.
3. **PlayaDB single-pin guard placed at `StaticAnnotationDataSource`, not in
   `PlayaObjectAnnotation`'s initializers.** Gating construction would have made the
   bulk paths' explicit `artAllowed`/`campAllowed` parameters unfalsifiable and broken
   the pure `MapRegionAnnotationFilter` tests, which pass tiers in on purpose.

## Verification

`xcodebuild test -scheme iBurnTests` (iPhone 17 Pro Max, iOS 26.5): **609 tests, 0
failures** (601 before, +8 new). No pbxproj / `DEVELOPMENT_TEAM` churn.

## Known gap (pre-existing, not introduced here) — **RESOLVED 2026-08-22**

Fixed by `iBurn/EmbargoUnlockScheduler.swift`; see
`Docs/2026-08-22-camp-tier-date-only-unlock.md` § "Date-rollover refresh". The scheduler
re-evaluates on launch, on `didBecomeActive`/`significantTimeChange` and on a timer armed
for the next unlock instant, and posts `.BRCEmbargoDidClear` on a locked → unlocked
transition. The original description follows.

`.BRCEmbargoDidClear` is posted on region entry and on passcode entry only — nothing
posts it when a tier's *date* rolls over with the app running. Both tier transitions
therefore refresh live only via that notification or a relaunch; every consumer
(`BaseMapViewController`, the list hosting controllers, `PlayaDBAnnotationDataSource`,
`UserMapViewAdapter`) re-reads both tiers when it fires, so nothing about this change
narrows what a post refreshes.
