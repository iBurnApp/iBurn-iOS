# 2026-08-09: Prototype merge + first 2026 placement data integration

## High-Level Plan

Two workstreams this session:

1. **Merge the bottom-search/Liquid Glass prototype** (`prototype/bottom-search-liquid-glass`, PR #253) into `2026-updates`, flipping the default so iOS 26 users get the search-tab layout out of the box. Older iOS releases resolve to the classic nav-bar search automatically.
2. **Integrate the first restricted 2026 camp placement data** (received 2026-08-09) into the data pipeline, with the hard rule that restricted content only ever lands in the **private** data repo (`iBurnApp/iBurn-Data-Private`) until gates open 8/30. Also refresh API data — which revealed the 2026 API has itself started serving camp placement to authorized keys.

## Technical Details

### Workstream 1: merge + search-tab default

- `iBurn/Preferences/Preferences.swift` — `userInterface.map.searchLayout` default flipped from `navigationBar` to `searchTab`. `MapSearchLayout.resolved` already routes any bottom-anchored layout to `navigationBar` below iOS 26, so pre-26 devices keep today's UI with no further changes.
- `iBurn/Map/MapSearchLayout.swift` — comments/display names updated (`Top (current)` → `Top (classic)`); no behavior change.
- `iBurnTests/TabConfigurationTests.swift` — five tests failed after the flip because they implicitly assumed the stored default was the classic layout (under `searchTab`, Events is layout-hidden and bar capacity is 4, so e.g. `testCurrentDefaultsToCanonicalOrderWhenNothingStored` no longer saw `current == .default`, and `testExplicitlyHiddenEventsStaysHiddenOnLayoutsThatWouldShowIt` recorded the user's "hide Events" as the layout default rather than a deliberate override). Fix: `setUp` now pins `MapSearchLayout.current = .navigationBar`; search-tab tests already opt in via `useSearchTabLayout()`. Full suite: 275 passing. (Note: an intermediate full-suite run reported 2 of these as still failing, but the class passed in isolation and the next full run was green — stale build artifact, not order-dependence.)
- Commit `cb1a415` on the prototype branch, then merge commit `76dd926` on `2026-updates` (`git merge --no-ff`), pushed; GitHub marked PR #253 merged at 2026-08-09T16:36Z.

### Workstream 2: restricted placement data (private repo only)

**Safeguard model (as practiced in 2025 and repeated here):** the `Submodules/iBurn-Data` submodule's `origin` is the private repo; the public mirror is a separate remote named `public` that only receives pushes after gates open. Restricted commits were pushed to `origin` (`3944138..03c641c` on `2026-updates`) and the `public` remote was never contacted. The app-repo submodule pointer already targets the private repo (commit `fbddd0b` earlier this month).

**The drop:** an OCR-derived dataset extracted from the 2026 public camp map PDF — camp records keyed by the same `uid` as the API's `camp.json`, with `location_string`/`location.*` fields matching our schema, an entrance-guess centroid Point (~1170 camps), and a border Polygon (~1170 camps). A big upgrade over 2025's anonymous letter-tracing LineStrings; no QGIS hand-reduction needed this year. Vendored (with the source PDF and corrections audit file) into `data/2026/placement/` in the private repo with a README covering provenance and restrictions.

**API refresh first (Aug 9):** `fetch_and_geocode.js -y 2026` — the 2026 API now returns the full `location` object for all 1191 camps (1186 with `location_string`); art 330→332, events 2430→2538, mv 495→494. Our offline geocoder placed 1180/1191 from addresses. Every textual location field in the drop matched the refreshed API byte-for-byte (the drop was evidently built from the same API snapshot), so the drop's real contribution is geometry: border polygons, label centroids, and GPS for 4 camps the geocoder couldn't place. First fetch attempt failed 401 (quoting bug extracting `BMORG_API_KEY`) and clobbered `update.json`; restored via `git checkout` before the successful retry — this failure mode is documented in `Docs/2026-07-18-api-data-refresh.md`.

**New tool — `scripts/apply_placement.js`** (private repo, plain node, no deps):

- Merges the placement drop into `APIData.bundle/camp.json` by `uid` with a **fill-only policy** (never overwrites non-null API values; logs conflicts — there were zero).
- Generates `Map.bundle/camp_outlines.geojson` (Polygon features) and `camp_labels.geojson` (Point features), both carrying `properties: {uid, name}` — 1170 features each, unlike 2025's anonymous shapes. Total 3.6 MB vs 2025's 24.7 MB.
- Bumps `update.json` `camps.updated` only when `camp.json` actually changed (keeps the script idempotent — verified byte-identical on re-run).
- Flags: `--year`, `--gps-source {geocoder|centroid}`, `--dry-run`, `--verbose`.

**GPS source judgment call:** `camp.json` GPS comes from our geocoder (street-intersection points; the API serves no coordinates). The drop's traced centroids sit a median 51 m away (p90 95 m) and include a few clearly bad ones (worst 1.9 km off; 4 camps > 500 m). Kept the geocoder as the default source; `--gps-source centroid` exists if we later prefer camp-body pins. 1184 camps have GPS; 7 have neither a usable address nor traced geometry; 21 have no drawn footprint (mobile/airport/support camps).

**Style change:** `camp-labels-big` in `iburn-{light,dark}.json` converted from `line` (2025's letter tracings) to `symbol` with `text-field: ["get","name"]`, sizes 9pt@z15→14pt@z20, wrapping at 8em, existing halo/text colors reused. Layer id/source unchanged (the id is load-bearing: `MapLayerManager.updateCampLayerVisibility()` toggles `camp-boundaries`/`camp-labels-big` behind `BRCEmbargo.canShowCampLocations()`). minzoom 17→15 to match the boundaries layer.

**Seeds regenerated** (all gitignored in the public app repo — verified with `git check-ignore`): `iBurn/PlayaDB-2026.zip` + `iBurnWatch/PlayaDB-2026.zip` via `playa-seed --fetch-media` (332 art / 1191 camps / 5032 occurrences / 494 MVs; 5 new thumbnails committed in the private submodule), and the legacy Yap seed `iBurn/iBurn-2026.zip` + archival copy (fresh onboarding import, `database2` at 6810 rows: 5284 events / 1191 camps / 332 art), which had been stale since Jul 18.

**Ship guards verified:** no `MOCK_LOCATIONS` sentinel; generated geojson contains no `camp_outlines_2025`/`camp_labels_2025` fixture markers; `MockDataShipGuardTests` (including `testBundledCampGeojsonIsNotPreviousYearFixture`) and `EmbargoTierTests` pass; deploy-workflow grep guard unaffected.

**Second drop, same day — direct polygon export.** A direct GeoJSON export of the current camp placement polygons arrived a few hours after the OCR drop (1183 Polygons keyed by the same uids, newer than the print PDF the OCR was traced from). Integrated as the preferred outline source:

- Vendored as `data/2026/placement/public_camps.geojson`; README rewritten with generic provenance (no sender/thread/tool-author references — the private repo mirrors to the public one after gates, so its files follow the same rule as `Docs/`).
- `apply_placement.js` now prefers the direct export's polygons (OCR `location.border` is the fallback — currently never needed: the export strictly supersedes it, 1170 shared + 13 direct-only + 0 OCR-only; 8 camps have no geometry from either source, down from 21). Where the sources disagree by >50 m (7 camps, worst 1.9 km), the direct export always lands closer to that camp's own address geocode — it fixes tracing errors.
- Labels moved to true area-weighted polygon centroids (shoelace over rings translated to a local origin — the naive absolute-coordinate form cancels catastrophically at BRC's longitude and had put 327/1183 labels outside their polygons; after the fix all 1183 are strictly interior). OCR entrance centroids remain the fallback for polygon-less camps.
- `camp.json`/`update.json` byte-identical → no seed rebuild needed. Outlines file shrank 41% (3.4→2.0 MB) despite 13 more features.

**Private submodule commits** (branch `2026-updates`, pushed to private origin only):

```
8f2112e  Vendor RESTRICTED 2026 camp placement drop
ea0997b  Add scripts/apply_placement.js: merge the placement drop into the bundles
1b062d4  2026 API refresh (Aug 9) + placement applied: camps are placed
8dcf572  Render camp-labels-big as text now that labels are Points
03c641c  2026 media: fetch 5 thumbnails new in the Aug 9 API data
77cafd4  Vendor the direct 2026 camp placement polygon export
8efae83  Draw camp outlines from the direct export, labels at polygon centroids
4908585  Describe placement provenance generically in docs and comments
```

**Open decision (user):** commit `8f2112e`'s *message* in the private repo names the data sender, the distribution channel, and the extraction tool. File contents are all sanitized (`4908585` covered the last two references, in the data repo's `CLAUDE.md` and `mock_locations.js`), but scrubbing the commit message itself means rewriting pushed history on the private `2026-updates` branch — not done without authorization. Must be decided before the private branch is mirrored to the public repo at gates-open; alternatives are a reworded rebase + force push (clean), or mirroring via a squashed/grafted publish instead of a direct branch push. *User decision 2026-08-09: fine for now — revisit at mirror time.*

### Validation

- Unit/package tests: iBurnTests 275 passing; PlayaAPI 71; PlayaDB 262; app scheme builds clean.
- Implementation-side sim check: with embargo unlocked, camp polygons and real text labels render in light and dark; Nearby lists placed camps with addresses and walk times.
- Locked-state validation (fresh install, pre-8/23): **FAILED — real embargo leak found and confirmed** (also observed live by the user). Details below.

### Locked-state validation: map pin leak (FIXED same day)

The dedicated locked-state pass (fresh erased sim, no unlock keys, embargo alert fired) found that while the style-layer gating works perfectly, a second annotation path leaks placement:

- **Root cause:** `iBurn/UserMapViewAdapter.swift` `mapView(_:regionDidChangeAnimated:)` fetches `playaDB.fetchObjects(in: region)` at zoom ≥ 16 and appends art (z≥16) and camp (z≥17) annotations with no `BRCEmbargo` check. The properly gated observation path (`PlayaDBAnnotationDataSource`, which snapshots `artAllowed`/`campAllowed`) never runs for camps by default because `kBRCShowCampsOnMapKey` defaults to false — so the ungated region path was the *only* camp-pin source, and pins carried the full playa address in the callout subtitle. Art pins (locked until 8/30) leaked the same way. This path predates placed data, so it had zero embargo coverage.
- Secondary: the Nearby list showed walk/bike times for camps while locked (proximity derived from embargoed coordinates); search already masks this as `? min`, so Nearby was brought in line.
- Everything else passed: embargo alert, style layers hidden (including with `showCampBoundariesAlways` on — it only widens zoom, both layers are ANDed with the embargo), camp detail "Restricted", search list, nearby card address line, Nearby "Show Map" block, unlock renders outlines + legible labels in light/dark, relock hides them; DB confirmed shipping 1184 camp GPS rows while the UI hid them.
- Sim-testing gotcha discovered: editing the app container plist with PlistBuddy does not stick (cfprefsd rewrites it from cache); the reliable unlock recipe is `xcrun simctl spawn <UDID> defaults write "<container>/Library/Preferences/com.trailbehind.iBurn2010" kBRCEntered2026EmbargoPasscodeKey -bool YES` with the app terminated. flows.md updated.

Fix (commits `836c34d` code+tests, `f9e1cf1` flows.md): a pure `MapRegionAnnotationFilter` (zoom + per-tier embargo, tiers injected — same shape as `CampLayerVisibility.resolve`) now gates the region-fetch path; events follow their host's tier exactly as `PlayaDBAnnotationDataSource` does; annotations refresh on `.BRCEmbargoDidClear`; the stale below-z16 annotation cache is cleared. Nearby list masks walk/bike as `? min` while an item's tier is locked (matching search). 10 new `EmbargoTierTests` cases cover the path (285 total tests passing). Re-validated in-sim: locked and relocked map states are byte-identical AX snapshots with zero annotations and "No pins visible"; unlocked shows art at z≥16 and camps at z≥17 with addresses, and Nearby shows real times.

### Round 2: camp pins on footprint centroids + one name per camp

User feedback after seeing the unlocked map: pins clustered at street intersections (geocoder points — only 365 distinct coordinates for 1184 placed camps, fanned onto 20 m circles) and every camp's name drew twice (style label + pin label).

- **GPS precedence in `apply_placement.js` is now `auto`: footprint centroid → address geocode → entrance centroid** (`--gps-source geocoder|entrance` remain for comparison). The centroid array written to `camp_labels.geojson` is the same array written to `camp.json`, so pin == label point by construction. Result: 1184 distinct coordinates (max 1 camp per coordinate), median pin movement 50 m, p90 95 m. Eventual goal recorded in the pipeline: pin at the center of the camp's street frontage on its road side (the entrance centroid approximates this and could become the default once trusted).
- Both seeds rebuilt (PlayaDB + watch zips, legacy Yap seed; all gitignored; BRCCampObject 1191 verified).
- **Name dedupe:** the pin's visible name is a `UILabel` in `LabelAnnotationView`, previously toggled on zoom alone. `CampLayerVisibility.resolve` now also takes `showCampsOnlyZoomedIn` + `zoomLevel` and returns `labelsMaximumZoom` (caps `camp-labels-big` at the camp-pin zoom threshold) and `campNamesDrawnByStyleLayer` (the pins' verdict) from one expression — double-draw is structurally impossible. Two refresh gaps fixed en route: Map Filter's Done now refreshes region annotations immediately, and raising a style layer's zoom cap goes through `reloadStyle` because MapLibre won't re-parse tiles built while the layer was capped (toggling `visibility` doesn't force it).
- Tests 285 → 290 (settings×zoom cross-check that the pin verdict always complements the layer's range); sim-validated over the densest camp block: locked empty, unlocked z≥17 one pin + one name per camp with style labels capped, z15–16 style labels only, filter-off keeps labels, relock empty again.
- Known residual: favorited camps (and "Camps (Always)") draw their pin image over the style text between z15–17 — name still appears once, but a `text-offset` in the style JSON would be the clean fix; deferred as it changes rendering for all camps.
- Commits: submodule `400c64b`/`b6408ae`/`907386b` (pushed to private origin), app `7f0dc81`/`002d2fe`.

### Round 3: style labels win everywhere; nearby card accessory line

User feedback: keep the styled map labels at all zooms and strip the text off camp pins instead (tap → callout still works); give the nearby card a dedicated location/time accessory line so the description survives embargo unlock; tighten the thumbnail→footer gap further.

- **Per-camp label split** (`33b11f4`): new `CampStyleLabelIndex` lazily loads the uid set from the bundled `camp_labels.geojson` off-main; pins for labeled camps show a bare glyph at every zoom (pure `PinLabelVisibility` verdict, nil-index = assume-labeled to avoid doubled-text flash; empty/missing file ⇒ every pin labels itself, so a pre-placement year degrades to today's behavior). `CampLayerVisibility.resolve` lost its zoom-capping inputs and the `reloadStyle` workaround is deleted. Residual: at z≥17 the pin glyph sits on the style text (same coordinate); clean fix is a `text-offset` in the style JSON (data submodule) if it bothers anyone.
- **Card accessory** (`4653ab5`): row is title / accessory (event timing · address, embargo-gated through `NearbyItem.address`) / description (2 lines when accessory absent, 1 when present). New arithmetic: text stack 56 ≤ thumbnail 60 → pageHeight 72, footer 28, **cardHeight 100** (was 112); the ~14 pt residual is gone. Text block scales via `@ScaledMetric` capped at XXXL — XXXL now grows the card clear of the footer; accessibility sizes truncate instead of overlapping.
- Tests 290 → **302**; sim-validated: one name per camp with callouts intact, filter/fallback toggles live-update without `reloadStyle`, locked state still renders nothing, card verified locked/unlocked for camps and events (mock-date pinned), Dynamic Type checked. flows.md updated (`1a6d039`).

### Round 4: pre-iOS-26 bar transparency (`e3670f5`)

User screenshot (iPhone 16 Pro Max, iOS 18.6): the map screen's nav bar and tab bar rendered fully transparent — tabs and search field floating on bare map. Root cause: `MainMapViewController.viewWillAppear` applies `Appearance.applyTransparentNavigationBarAppearance`/`applyTransparentTabBarAppearance` (clear background, `backgroundEffect = nil` on all appearance slots) unconditionally; on iOS 26 the system paints Liquid Glass behind the bar, below 26 there's nothing. Fix in `Appearance.swift`: both transparent builders now `guard #available(iOS 26, *)` and fall through to the standard `systemChromeMaterial` pair below. iOS 26 path byte-identical.

Validated on a fresh iOS 18.6 sim (bars show proper material on all five tabs, nav-bar search works end-to-end, locked-state embargo intact on that runtime) and on iOS 26.5 (glass chrome unchanged). 302 tests passing, both destinations build clean. flows.md §8 notes the version split.

Known follow-up found on 18.6: the classic-layout search results overlay is see-through (`GlobalSearchHostingController.applyBackground` only gets `isOverlay` from the iOS 26 bottom-search path, so pre-26 lands on a transparent background over the map). Needs a background/material decision on `GlobalSearchView`. Also: CLAUDE.md still references a `PlayaKitTests` scheme that no longer exists.

## Context Preservation

- The 2026 API serving placement means future refreshes (`fetch_and_geocode.js`) keep camps placed without the drop; `apply_placement.js` re-applies geometry on top and is safe to re-run after any refresh (fill-only + idempotent).
- OTA note: existing installs receive data via the public `UPDATES_URL` endpoint, which is fed from the public repo — pushing `public` after gates open is what lights up OTA placement for released builds. Until then, only new builds carry (embargo-hidden) placement.
- Restricted-data hygiene for future sessions: screenshots of an unlocked map are restricted content — keep them out of `Docs/` (public repo); job tmp only.

## Cross-References

- `Docs/2026-08-08-map-config-tabs-search-scope.md` — prototype rounds 5–9 (merged today)
- `Docs/2026-08-06-placement-data-embargo-and-passcode.md` — embargo gating + passcode work; its Phase 3 (QGIS reduction plan) is now obsolete thanks to the uid-keyed drop format
- `Docs/2026-07-18-api-data-refresh.md` — refresh procedure + seed regeneration
- Private repo: `data/2026/placement/README.md` — drop provenance

## Expected Outcomes

- Fresh installs on iOS 26 land on the search-tab layout; older iOS gets the classic nav-bar search.
- Builds ship real 2026 camp placement, fully hidden until 2026-08-23T07:01Z (camp tier), passcode, or gates; map outlines + text labels appear on unlock.
- Re-running the pipeline after future API refreshes: `node scripts/apply_placement.js` in the private repo, then `playa-seed --fetch-media`, then commit (private) and bump the submodule pointer.

---

# Workstream 4: Tappable style labels + camp pin suppression (`1508725`)

**Problem (user report + screenshot).** At z≥15 the style layer draws camp names, but the purple
pin glyph still sits on top of the text, and the pin existed only as the tap entry point
(callout → detail). User preference: make the labels themselves tappable and drop the pins.

**Change.** Tapping a `camp-labels-big` label now pushes camp detail directly — a new
`UITapGestureRecognizer` on the map (installed in `MapViewAdapter.init`, `require(toFail:)`-ed
against every built-in map tap recognizer per MapLibre's documented pattern) queries a 44×44pt
box via `visibleFeatures(in:styleLayerIdentifiers:)`, reads the feature's `uid`, and routes
through the existing per-screen `onPlayaInfoTapped` closure (fallback: direct
`fetchCamp` + push). Embargo is re-checked at tap time so a stale tile can't open a locked camp.

Pin suppression: new pure `CampPinVisibility.pinIsHidden(campUID:isFavorite:styleDrawsCampNames:styleLabeledCampUIDs:)`
in `CampStyleLabelIndex.swift`; applied via an overridable `MapViewAdapter.shouldDisplay(_:)`
that only `UserMapViewAdapter` (main map) overrides — so `StaticAnnotationDataSource` screens
(favorites/camp-list "show on map") structurally keep every pin. Favorited camps keep their pins
(`PlayaObjectAnnotation.isFavorite`, set by the `onlyFavorites` observations). `nil` (still-loading)
index = keep the pin (opposite reading from `PinLabelVisibility`, documented in place). Pin set
rebuilds when the `campNamesDrawnByStyleLayer` verdict flips (region change, embargo clear, index
load); Map Filter "Done" also reloads.

**Validated** (sim, unlocked, z17): style labels with zero purple pins (a11y snapshot: 1 camp
button — `Westlandia`, the one placed camp with GPS but no geojson label — among ~18 in view);
camp-names toggle round-trips; favorite + unlabeled camps keep pins; relocked = no labels, no
pins. Tap path verified at both ends via lldb (recognizer wired with must-fail on the map's
single/double/two-finger taps; feature query returns `{name, uid}` unlocked, empty locked).
310 tests (8 new). Known edges: a favorite's bare pin still overlaps its style text
(`text-offset` in the style JSON remains the clean fix, data submodule); crossing z15 while
dragging a user pin cancels the edit (verdict-flip reload calls `clearEditingAnnotation`).

---

# Workstream 5: Nearby "happening now-ish" — duration cap, filter sheet, ordering

## High-Level Plan

**Problem (user report).** The Nearby screen and the map's nearby card were supposed to answer
"what's near me right now", but (a) 10–12 hour "amenity listing" pseudo-events (open bars,
stamp stations, mailboxes) flooded the list because neither surface capped occurrence
duration, and (b) the user also saw events that "don't start for many hours". They asked for
the Events tab's filter mechanism — especially its 6 h default max duration — to be reused,
with a filters entry point in the Nearby nav bar.

**Solution.**

1. One shared, persisted `EventFilter` for both Nearby surfaces (`NearbyEventFilterStore`),
   defaulting to the same 6 h cap the Events tab uses, applied **in SQL** (`EventFilter.maxDuration`).
2. A filter button in the Nearby nav bar presenting the existing `EventFilterSheet`.
3. A deliberate in-window ordering (`NearbyEventOrdering`) so just-started / starting-soon
   events outrank long-runners.
4. The "starts many hours from now" diagnosis (below) — a display-vs-filter date mismatch
   under Warp.

## Item-4 diagnosis: the far-future events

There is no "upcoming" section on the Nearby screen — `sections` only ever contains
`happeningEvents`, and that is gated by `isInNearbyWindow(now: effectiveDate)` (starts within
30 min, hasn't ended). The window was not leaking. The **labels** were.

`NearbyViewModel.effectiveDate` is `timeShiftConfig?.date ?? .present`, but the published
`now` that `NearbyView` handed to `EventObjectOccurrence.timeDescription(now:)` was
unconditionally `.present`:

```swift
@Published var now: Date = .present          // timer: self.now = .present
...
rightSubtitle: event.object.timeDescription(now: viewModel.now)
```

So whenever Warp was active — and `UserSettings.nearbyTimeShiftConfig` **persists across
launches**, so a warp set once stays on until explicitly reset — the list was filtered at the
warped date while every row was described against real wall-clock time. `timeDescription`
then fell through both its `isStartingSoon` and `isCurrentlyHappening` branches to
`defaultTimeText`, rendering "Wed 12:00pm (4h)": a date/time hours or days from now, on every
row. Reproduced in the simulator (warp to Wed Sep 2 12:00 PM while real now is Aug 9) before
the fix.

**Fix:** `now` is now maintained as the effective date — set in `init`, in `timeShiftConfig.didSet`,
and on each 60 s timer tick — so filtering and labeling always share one clock. Post-fix the
same warped list reads "12:00pm (4h left)", "12:00pm (2h left)".

The second half of the report (events that *look* far away) was the amenity listings
themselves: a 12 h occurrence that started at 09:00 rendered "9:00am (7h left)" and sorted
above everything, which the 6 h cap plus the new ordering both address.

## Technical Details

### New files

- **`iBurn/ListView/EventFilterStorage.swift`** — the persistence rules, extracted from
  `EventListViewModel` so both screens share them: `defaultMaxDuration` (6 h),
  `durationStorageKey(for:)`, `load/saveMaxDuration`, `load/saveFilter`, plus
  `EventFilter.eventListDefaults` / `.nearbyDefaults` and `matchesSheetDefaults(_:includingExpired:)`.
  The duration is still stored under its own key as a `StoredMaxDuration` enum so
  "never chosen" (→ 6 h) stays distinct from "explicitly Any" (→ no limit); the package
  default in PlayaDB stays `nil`.
- **`iBurn/ListView/NearbyEventFilterStore.swift`** — `@MainActor ObservableObject` holding the
  Nearby `EventFilter` under key `nearbyEventFilter`. `.shared` is what both view models bind
  to; a shared object rather than a notification, so a change made in the Nearby sheet
  republishes to the card still alive underneath it in the map tab's stack.
  `observationFilter(region:)` forces `includeExpired = true` and strips per-query state
  (dates, search text, `activeWindow`, `happeningNow`).
- **`iBurnTests/NearbyEventFilterTests.swift`** — 18 tests (below).

### Modified

- **`iBurn/ListView/NearbyViewModel.swift`** — takes an injectable `filterStore` (`nil` →
  `.shared`; not a `= .shared` default argument, which Swift evaluates in a nonisolated
  context); subscribes to `$filter` and restarts the event observation (the cap is a SQL
  predicate, so a filter change must re-query, not re-filter); event query is now
  `filterStore.observationFilter(region:)`; `happeningEvents` is internal and sorted via
  `NearbyEventOrdering`; `now` follows `effectiveDate` (see diagnosis).
- **`iBurn/Map/NearbyCard/NearbyCardViewModel.swift`** — same store injection + subscription;
  `startEventObservation` uses `observationFilter(region:)`; `orderedItems` sorts its
  in-window events with `NearbyEventOrdering`.
- **`iBurn/ListView/NearbyItem.swift`** — added `NearbyEventOrdering` (pure, tested):
  sort key `(phase, offset, uid)` where phase 0 = not yet started (soonest first) and
  phase 1 = already started (most recently started first); `uid` breaks ties so rebuilds
  (every location fix, every timer tick) don't shuffle rows.
- **`iBurn/ListView/NearbyView.swift`** — trailing filter button (AX label
  "Filter Nearby Events") beside the map button, filled icon when non-default, presenting
  `EventFilterSheet` bound to `$filterStore.filter`.
- **`iBurn/ListView/EventFilterSheet.swift`** — parameterized: `defaultFilter`
  (what Reset restores / what "is default" compares against), `showsExpiredToggle`, `title`.
  Events-tab behavior unchanged by the defaults.
- **`iBurn/ListView/EventListViewModel.swift`** — persistence delegated to
  `EventFilterStorage`; `defaultMaxDuration` kept as an alias.
- **`iBurn/ListView/EventListView.swift`** — badge now uses `matchesSheetDefaults`.

### Design decisions

- **`includeExpired` is hidden on the Nearby sheet, not merely ignored.** Nearby's time gate
  is the in-memory now-window at the *effective* date; PlayaDB's expiry predicate compares
  against real wall-clock now, so honoring the toggle would empty the list whenever the user
  warped into the past. The store forces it `true` for observations, and the sheet's section
  header becomes "Favorites" (it only holds "Only Favorites" then). `onlyFavorites` and the
  event-type toggles compose with the nearby query and are kept.
- **One setting for screen and card.** They already share `isInNearbyWindow` precisely so the
  two lists can't disagree; a per-surface cap would have put a 12 h listing back on the map
  the moment the user swiped to it.
- **Ordering.** Ascending start time buries the interesting rows. Descending everywhere would
  put a listing that started 10 minutes ago above one starting in 5. The two-phase key is the
  smallest rule that keeps "you can still make this" at the top.

## Tests

`iBurnTests/NearbyEventFilterTests.swift` (18 new): fresh-install 6 h default; `includeExpired`
pinned true through reload and `observationFilter`; explicit "Any" vs. unset; explicit limit
round-trip; event-type round-trip; Nearby key independent of `eventListFilter`;
`observationFilter` strips per-query state; the cap reaching both view models' queries; a
filter change re-querying **both** surfaces from the one store; a regression pinning that
nothing outside the window reaches `sections` (4 h out, 26 h out, and ended rows all dropped);
`now` following a warp; and five ordering tests (phase precedence, soonest-first, most-recent-first,
`startDate == now` counting as started, uid tie-break stability).

**Full suite: 328 passing** (310 before), 0 failures. App scheme builds clean on iOS 26.5
(iPhone 17 Pro Max) and iOS 18.6 (iPhone 16 Pro Max, by UDID).

## Simulator validation

Mock date `2026-09-02T19:00Z`, `simctl location set 40.79169,-119.21120` (between Orphan
Asylum, Nom De Plume and Maison Phi — 9 in-window events inside the card's 100 m, 7 of them
> 6 h):

- Nearby screen at the 6 h default lists only short/near-term events, top three all
  "12:00pm (Nh left)" — warp-correct labels (the item-4 fix).
- Filter button opens "Filter Nearby Events": Favorites / Max Duration (6h) / Event Types,
  no expired toggle, no Reset while at defaults.
- Dragging the slider to **Any** updates the list live — the 12 h `'Dust & Ink ayslum'` and
  friends appear, ordered by most-recent start under the just-started ones.
- Relaunch: the choice persists (`nearbyEventFilter.maxDuration` = `{"unlimited":{}}`,
  filter icon filled).
- The map card's page dots read **9 at "Any"** and **2 after Reset** (`{"limited":{"_0":21600}}`),
  updating without leaving the map — the cap reaches the card through the shared store.

Screenshots (job tmp): `01-nearby-capped-6h.jpg`, `02-filter-sheet.jpg`,
`03-nearby-any-uncapped.jpg`, `04-card-any-9items.jpg`, `05-card-6h-2items.jpg`.

`.claude/skills/drive-app/references/flows.md` gains a "Nearby screen (list)" subsection for
the new button/cap/ordering, plus the note that a prefs-plist file edit *does* stick if you
`launchctl kickstart -k system/com.apple.cfprefsd.xpc.daemon` in the sim afterwards (needed
for data-typed keys like `nearbyEventFilter.maxDuration`).

## Expected Outcomes

- Nearby (screen and card) shows only what is happening now or starting within 30 minutes,
  with 10–12 h amenity listings hidden by default and reachable by setting Max Duration to Any.
- Timing labels always agree with the date the list was filtered at, warped or not.
- One filter choice governs both Nearby surfaces and survives relaunch.

---

# Favorites moves off the tab bar into a floating button (searchTab layout)

## High-Level Plan

**Problem.** On iOS 26 the default `MapSearchLayout.searchTab` spends a tab bar slot on
`UISearchTab`, leaving four slots for app tabs. Events was the tab that gave way, which put
a browse surface with nowhere else to live behind a More row.

**Solution (prototype).** Trade the *Favorites* slot instead, because Favorites can keep a
better entry point than a tab: a Slack-style floating circular button above the bar's
trailing corner that presents Favorites as a sheet from any tab. Events returns to the bar.
Pre-iOS-26 layouts and the non-`searchTab` layouts on 26 are untouched — classic five tabs
including Favorites, no floating button.

**Key changes**
1. `TabConfiguration.layoutHiddenByDefault` returns `[.favorites]` (was `[.events]`) when
   `searchTabOccupiesBarSlot`. Everything downstream — Customize Tabs, the More rows,
   capacity clamping, visibility overrides — already keys off this one property.
2. New `FavoritesFloatingButton` + `FavoritesFABVisibility` rule.
3. `TabController` installs the button on its own view, updates it on every `rebuildTabs()`,
   and presents Favorites as a `.large` sheet.

## Technical Details

### `iBurn/Tabs/TabConfiguration.swift`
`layoutHiddenByDefault` → `[.favorites]` under the search tab; doc comments rewritten. No
other logic changed: displaced-to-More, user overrides, capacity clamp and Reset all keep
working because they were never Events-specific.

### `iBurn/Tabs/FavoritesFloatingButton.swift` (new)
```swift
enum FavoritesFABVisibility {
    static func isVisible(searchTabActive: Bool, favoritesDisplaced: Bool) -> Bool {
        searchTabActive && favoritesDisplaced
    }
}
```
Pure rule so it can be tested without a window; a `@MainActor` convenience reads the live
configuration. The view is a 56pt `UIGlassEffect(style: .regular)` circle (blur fallback
below 26) with `heart.fill`, AX label "Favorites", identifier `favoritesFloatingButton` —
the `SidebarButtonsView` treatment at primary-entry-point size rather than the map column's
40pt.

### `iBurn/TabController.swift`
- Lazy `favoritesButton` on the tab bar controller's own view, so it is present over every
  tab. Installed on first need; layouts that keep Favorites on the bar never build it.
- Constraints: trailing `view.safeAreaLayoutGuide` −16, bottom `tabBar.topAnchor` **−36**.
  Anchoring to the bar (not the safe area) keeps the gap constant whether or not a tab
  accessory is installed. **36 rather than a snug 12 because MapLibre's attribution ⓘ sits
  in that same corner on the Map tab and must stay tappable** — verified by screenshot; at
  −12 the heart covered it.
- `presentFavorites()` builds the screen from `BRCAppDelegate.createFavoritesViewController()`
  (same factory as the tab and the More row, so the SwiftUI feature flag is respected),
  wraps it in `NavigationController`, `.large` detent, grabber visible.
- **Search-mode hiding.** Selecting the search tab collapses the bar into a search field but
  triggers *no layout pass* on the tab bar controller — confirmed with a temporary `NSLog` in
  `viewDidLayoutSubviews`, which fired only twice at launch and never on tab change. So
  `selectedTab is UISearchTab` at layout time never ran. Fixed by routing the search
  controller's activation through the factory:
  `GlobalSearchTabFactory.makeSearchTabRoot(dependencies:searchActivationDidChange:)` — its
  `Updater` now also conforms to `UISearchControllerDelegate` and reports
  `willPresent`/`willDismiss` into `TabController.searchIsActive`. `viewDidLayoutSubviews`
  still handles the bar sliding off screen.

### `iBurn/Tabs/CustomizeTabsView.swift`
`hiddenFooter` was hardcoded to Events; now it names whichever tab
`layoutHiddenByDefault` displaced, and adds "The heart button above the tab bar opens it
from any screen." for Favorites.

### `iBurn/Map/MapSearchLayout.swift`
`.searchTab` summary now reads "Search button beside the tab bar; Favorites moves to a
floating button."

### Tests — `iBurnTests/TabConfigurationTests.swift`
Search-layout block swapped Events↔Favorites (`testSearchTabLayoutHidesFavoritesByDefault`,
`…PutsFavoritesInMore`, `…UserCanPutFavoritesBack…`, `…ExplicitFavoritesChoiceSurvives…`,
etc.). Structural invariants preserved:
- `testCapacityClampOnLayoutSwitchIsNotAUserChoice` now gives *Favorites* the explicit
  "on the bar" override, so the clamp (not the layout default) is what empties the slot —
  otherwise the test no longer exercised clamping at all.
- The partition-integrity edit sequence now hides Events and un-hides Favorites, mirroring
  the new default.
- `testExplicitlyHiddenEventsStaysHiddenOnLayoutsThatWouldShowIt` kept as-is — it is now the
  stronger direction (a hand-hidden Events stays hidden on the layout that would show it).
Two new tests pin the FAB rule: the pure truth table, and tracking of the live configuration
(re-adding Favorites to the bar hides the button; Reset brings it back).

**330 tests passing** (328 before, +2), 0 failures, iPhone 17 Pro Max iOS 26.5.

## Simulator Verification (iPhone 17 Pro Max, iOS 26.5)

- Tab bar: Map / Nearby / Events / More + search; heart floats above the trailing corner
  clear of the attribution ⓘ.
- Tap → Favorites sheet (`.large`, grabber); tapping "Snuggles" pushes the detail *inside*
  the sheet; drag-down dismisses back to the map.
- Search tab → heart gone; Close → heart back.
- More still lists Favorites as its first row.
- Customize Tabs → remove Events, add Favorites → bar shows Map/Nearby/More/Favorites +
  search and the heart disappears. Reset restores the default and the heart.
- iOS 18.6 (iPhone 16 Pro Max): classic five tabs including Favorites, search under the nav
  bar title, no floating button.

Screenshots (temp): `/tmp/claude/iburn-favorites-fab/01-map-fab-ios26.png`,
`02-favorites-sheet.png`, `03-search-mode-no-fab.png`,
`04-customize-favorites-on-bar-no-fab.jpg`, `05-detail-inside-sheet.jpg`,
`06-ios186-launch.png`, `07-customize-tabs-default.png`.

## Caveats / Follow-ups

- Pushing the **map** from inside the Favorites sheet stays in the sheet (as does detail
  paging). Acceptable for the experiment; a real version would dismiss and push on the
  active tab's navigation stack.
- The sheet has **no Done button** — dismissal is grabber/swipe only. `FavoritesView`
  already owns both trailing toolbar slots, and adding a UIKit bar button item to a
  SwiftUI-toolbar hosting controller fights SwiftUI for the navigation item.
- The −36 offset is tuned against the Map tab's attribution button; if map chrome moves,
  re-check the corner.
- `TabController.eventsIsDisplacedFromTabBar` is still dead code (was already unused).

## Expected Outcomes

On iOS 26 with the default search-tab layout: four primary tabs (Map, Nearby, Events, More)
plus native search, with Favorites one tap away from every screen via the floating heart and
still listed in More. Pre-26 and the other layouts are visually and behaviorally unchanged.

# Floating button, round 2: real alignment, configurable action

## High-Level Plan

Three refinements to the floating button experiment above, plus the collision it was
working around:

1. **Align it with the search circle and tighten the gap.** Round 1 pinned the button to
   the safe-area trailing edge with a 36pt gap above the bar. Both numbers were
   compromises: the trailing inset only *approximately* lined up with the detached search
   circle, and the 36pt gap existed solely to clear MapLibre's attribution ⓘ.
2. **Outline glyph** instead of the filled heart.
3. **Make the button configurable** — on/off, and *what it opens* — from Customize Tabs.

## Technical Details

### Alignment: measure the circle, don't guess at it

`TabController.searchTabCenterX()` walks the tab bar's view tree for the trailing-most
round item (square bounds, 36–80pt, in the bar's trailing quarter) and returns its center
in the controller's coordinates; `alignFloatingButtonWithSearchTab()` drives a `centerX`
constraint from it, guarded so a sub-point delta never re-enters layout. No private
symbols, no view-class names — if nothing matches (another bar layout, a regular-width
bar), the button keeps the trailing inset it was installed with.

The part that actually made it work: **`tabBar.layoutIfNeeded()` before measuring.** Layout
is top-down, so at `viewDidLayoutSubviews` the bar has a frame but every view inside it is
still a zero rect. The first version of this shipped without the forced pass, found no
candidate, and silently sat on the fallback — visually a ~8pt offset that looked like a
tuning problem rather than a measurement that never happened. A view-hierarchy dump
(temporary `NSLog`, since removed) is what surfaced it: the search circle is a `_UITabButton`
under `_UITabBarAuxiliaryView` → `_UITabBarPlatterView`, i.e. genuinely inside the bar, just
not laid out yet.

Verified by pixel measurement rather than by eye: FAB center and search-circle center are
both x = 1163.5px on an iPhone 17 Pro Max at 3x, with a 4-tab bar and again with a 2-tab
bar. Vertical gap is now `tabBar.topAnchor` −12 (measured 12.3pt).

### Attribution: hidden, not moved

The first attempt shifted MapLibre's ⓘ left by the button's width
(`attributionButtonMargins`). Per product direction this became: hide it outright.
`MLNMapView.brc_setDefaults` now sets `attributionButton.isHidden = true`, which covers
every map in the app from one seam. Map-data credit remains on the Credits screen and in
the Settings acknowledgements (`LicensePlist`), and the MapLibre wordmark logo is
untouched at bottom-left. Note the *accessibility* element "About this map" still shows up
in UI snapshots — MapLibre publishes it from the map view itself — so verify this one from
a screenshot.

### Configurability

- `iBurn/Tabs/FloatingActionButton.swift` (was `FavoritesFloatingButton.swift`) now holds
  `FloatingActionButtonAction` (`favorites` | `events` | `nearby`, each mapping to a
  `TabIdentifier`, an outline SF Symbol, and the matching `BRCAppDelegate.create*` factory),
  `FloatingActionButtonSettings` (the two preferences + a `.floatingActionButtonDidChange`
  notification on write), and `FloatingActionButtonVisibility` with the widened rule.
- Preferences: `userInterface.fab.enabled` (Bool, default true) and `userInterface.fab.action`
  (String, default `favorites`, unknown values falling back to `favorites`).
- Visibility rule is still pure: `searchTabActive && enabled && actionDisplaced`.
- `CustomizeTabsView` grows a **Floating Button** section (toggle + `.menu` picker), shown
  only on the search-tab layout. `.menu` style because the list is permanently in edit mode,
  where a navigation-link picker isn't reliably tappable. Bindings write through on set
  (`Binding.writingThrough`) rather than `onChange(of:initial:)`, which needs iOS 17 while
  the app still builds back to 16.6.
- Nearby's glyph is `safari` (a compass, matching `BRCCompassIcon`); `location` renders the
  same arrow as the map's tracking button.

### The picker's awkward case, handled in copy

Choosing Events or Nearby hides the button under the default layout, because those tabs are
on the bar. Rather than filtering them out of the picker (which hides the capability), the
section footer explains the consequence and the fix: "*Events* is on the tab bar, so the
floating button is hidden — one way in is enough. Remove *Events* from the bar above to
bring the button back." Verified end-to-end: pick Events → button vanishes; remove Events
from the bar in the section above → button returns with a calendar glyph and opens the
Events list.

## Tests

`iBurnTests/TabConfigurationTests.swift`: the two FAB tests became seven — a full truth
table over the three conditions, live-configuration tracking, the enabled flag, the
action-still-has-a-tab case, preference defaults, every action mapping to a hideable tab,
and unknown-stored-action fallback. **335 tests, 0 failures** on iOS 26.5 (was 330).

## Simulator validation (iPhone 17 Pro Max, iOS 26.5)

Screenshots (temp): `/tmp/claude/iburn-fab-round2/` — `01-map-fab-aligned.png`,
`02-alignment-closeup.png`, `03-favorites-sheet.png`, `04b-customize-tabs-crop.png`,
`05b-fab-off-crop.png`, `06-action-picker-menu.png`, `07b-crop.png`,
`08b-events-fab-crop.png`, `09-events-sheet.png`, `11-nearby-sheet.png`,
`12b-nearby-fab-crop.png`.

Also built clean for iOS 18.6 (iPhone 16 Pro Max), where none of this exists.

## Caveats / Follow-ups

- The round-item heuristic is a *measurement*, not a contract. If a future bar layout puts
  another circular ornament at the trailing end, the button follows that instead. The
  fallback keeps it in a sane corner either way.
- `Reset` in Customize Tabs still only resets the tab arrangement; the floating button's
  two preferences survive it. Arguably it should clear them too.
- Simulator hygiene: neither `simctl spawn defaults delete` nor editing the container plist
  clears these preferences — `cfprefsd` rewrites the file from cache. Use the app's own UI
  (already noted in the flows doc).
