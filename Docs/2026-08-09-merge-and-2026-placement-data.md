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

---

# Workstream 3: "drop the person" — a transient look-from-here location on the map

## High-Level Plan

**Problem.** The map's nearby card, and the Nearby screen behind its "See all", can only
answer "what's around *me*". There is no way to ask "what's around *there*" — planning a
route, or scouting a corner of the city you aren't standing in, means walking there first.

**Solution.** Long-press anywhere on the main map to stand a little person marker on that
spot (the Street View pegman idea). While it is standing there:

- the nearby card re-sources to it — its ~100 m of art/camps/events, and every distance,
  are computed from the marker's coordinate, not the device's;
- the card grows a header line naming the spot, resolved through the app's existing offline
  reverse geocoder;
- "See all" pushes the Nearby screen already measured from the same spot;
- long-pressing elsewhere moves the person; the card's "Hide", and a remove button in the
  marker's own callout, put it away and hand the card back to GPS.

**The override is deliberately transient.** It lives only in the two view models, is never
written to `UserSettings` or PlayaDB, and is gone after a relaunch. That is the whole reason
it is a separate concept from Warp (`TimeShiftConfiguration`), which *is* persisted — the
person changes *where* you're looking from, never *when*.

## Technical Details

### New files

- `iBurn/Map/DroppedPersonAnnotation.swift` — the ephemeral annotation
  (`MLNPointAnnotation` subclass conforming to the app's `ImageAnnotation`), the runtime
  marker artwork (`DroppedPersonMarker`), and two small coordinate-identity helpers
  (`isSameCoordinate(as:)`, `isSameSourceLocation`) used to tie asynchronous geocode results
  back to the drop that asked for them.
- `iBurnTests/DroppedPinSourceOverrideTests.swift` — 18 tests, below.

### The override seam, on both surfaces

- `iBurn/Map/NearbyCard/NearbyCardViewModel.swift` — new `sourceLocationOverride` /
  `sourceLocationAddress` published state; `currentLocation` becomes
  `sourceLocationOverride ?? rawLocation`, which is enough to move `searchRegion`, the radius
  gate and every per-item distance in one edit. `setSourceLocationOverride(_:)` restarts the
  region observations (the point is that a *different* circle is queried);
  `setSourceLocationAddress(_:for:)` is coordinate-checked so a late geocode can't label a
  spot the person has already left. The location stream still updates `rawLocation` while
  pinned — so clearing snaps to a *current* fix — but returns early before any recenter.
- `iBurn/ListView/NearbyViewModel.swift` — the same pair, plus precedence:
  **dropped pin > Warp location > device**. The two explicit choices retire each other rather
  than silently stacking: setting a Warp *location* clears the pin override (most recent
  explicit action wins), and a time-only Warp leaves the pin standing. `isSourcePinned`
  replaces the old `timeShiftConfig?.location == nil` guard in the location stream so either
  kind of pinning suppresses GPS-driven re-queries. Nothing here touches
  `UserSettings.nearbyTimeShiftConfig`.

### Plumbing

- `DependencyContainer.makeNearbyViewModel(locationOverride:)`,
  `NearbyListHostingController(dependencies:locationOverride:)` and a Swift-only
  `BRCAppDelegate.createNearbyViewController(locationOverride:)` overload widen the chain.
  The no-argument `@objc` spelling is kept as-is because `BRCAppDelegate.m` calls it for tab
  setup and a default argument would have renamed the selector. The other two callers
  (`MoreViewController`, `FloatingActionButton`) are untouched.
- `NearbyCardHostingController` passes `viewModel.sourceLocationOverride` into "See all", and
  clears it from "Hide".
- The hosting controller reverse-geocodes the handed-over location and applies the result
  through the same coordinate-checked setter.

### Map side

- `UserMapViewAdapter` owns the marker: `dropPerson(at:title:)`, `updateDroppedPersonTitle`,
  `removeDroppedPerson(notifyHost:)`, plus the annotation-view, callout-accessory and
  callout-tap branches. It is held outside both annotation lists on purpose —
  `reloadAnnotations()` and `refreshRegionAnnotations()` each remove only what they own, so
  the person survives every pan, filter change and embargo unlock without being re-added.
  `keyForAnnotation` returns nil for it (untracked, always added) and `campUID(for:)` returns
  nil, so the camp pin-suppression and style-label logic ignore it entirely.
- `MainMapViewController` installs the `UILongPressGestureRecognizer` (named
  `iBurn.dropPersonLongPress`, 0.45 s) directly on the map view, following
  `MapViewAdapter.installStyleLabelTapRecognizer()`'s naming/idempotence pattern. Scoped to
  this screen rather than to `MapViewAdapter` because the card only exists here — detail maps
  and "show on map" list maps keep their plain behaviour.

### Design calls worth recording

- **Marker artwork is generated, not shipped.** The bundle has teardrop pins and
  `BRCUserPin*` glyphs but no person, so the marker is an SF Symbol figure drawn into a
  circular chip with a white ring and a drop shadow. The fill is a fixed saturated blue
  rather than the app's amber accent: the light base map is tan, and amber-on-tan is the one
  combination that disappears.
- **Removal affordance is the callout's ⊗**, not tap-to-remove. The callout is also what
  *shows* the reverse-geocoded address, and a marker that vanishes on a stray tap is easy to
  lose by accident.
- **Card height** is `page + footer + (header ? header : 0)`, factored out as a pure
  `NearbyCardView.cardHeight(pageHeight:headerHeight:)` so the arithmetic is unit-tested. The
  header line follows Dynamic Type through the same capped `@ScaledMetric` pattern the row's
  text stack uses (24 pt at default type, so 100 pt → 124 pt).
- **Legacy path caveat.** The UIKit `NearbyViewController` (feature flag `useSwiftUILists`
  off) ignores the override. Its location source is wired through its own *persisted*
  time-shift configuration, and this override must not be persisted, so honoring it there is
  a rewrite rather than a parameter. Documented at the factory.
- **"Use My Location" on the Nearby screen clears that screen only** — the map keeps its
  person until removed there. Two independent view model instances; making them one shared
  source would have meant persisting or globally publishing the override.

## Tests

`iBurnTests/DroppedPinSourceOverrideTests.swift` — 18 new tests covering precedence on both
view models, region re-centering, the GPS stream not clobbering an active override, clearing
restoring device sourcing, stale-geocode rejection, the warp/pin interaction in both
directions, non-persistence, and the card-height arithmetic. Two test doubles: a location
provider whose stream stays open (the shared `MockLocationProvider` finishes immediately,
which can't distinguish "pinned" from "no updates"), and a recording event provider that
captures the region each observation was started with.

**353 tests, 0 failures** on iOS 26.5 (was 335). Also built clean for iOS 18.6
(iPhone 16 Pro Max, by UDID).

## Simulator validation (iPhone 17 Pro Max, iOS 26.5)

Location `40.7864,-119.2065`, embargo unlocked, all three card types enabled. Verified:
long-press drops the marker; the card re-sources (different objects, different distances) and
grows its geocoded header; long-pressing elsewhere moves it (only ever one on the map);
"See all" opens the list already measured from the marker with its own banner and
"Use My Location" reset; the callout's remove button and the card's "Hide" both clear
everything back to GPS — the post-removal accessibility snapshot hashes identical to the
pre-drop baseline; and a relaunch comes up with no marker, confirming transience.

Screenshots (temp): `/tmp/claude/iburn-person-drop/` — `01-baseline-device-sourced.jpg`,
`02-person-dropped-card-header.jpg`, `03-nearby-tab-device-sourced.jpg`,
`04-nearby-see-all-pin-sourced.jpg`, `05-person-callout-remove.jpg`,
`06-cleared-back-to-device-after-relaunch.jpg`.

Flow documentation: `.claude/skills/drive-app/references/flows.md` gains a
"Drop the person (long-press 'look from here')" section under §6, including the automation
trick for choosing a drop coordinate (long-press an annotation button — the recognizer is on
the map view, so touches inside any annotation reach it).

## Caveats / Follow-ups

- **Long-press then drag still pans.** The recognizer fires at 0.45 s and MapLibre's pan can
  still begin afterwards if the finger keeps moving. The marker stays at the coordinate it
  was dropped on, so the consequence is cosmetic, but a `require(toFail:)` relationship was
  rejected as the cure — it would delay every pan by the press duration.
- **With the card switched off, a drop has no visible effect** beyond the marker and its
  callout, since the card is the only thing that surfaces the override on the map. Dropping
  the person deliberately does *not* re-enable the card (that would be writing a preference
  the user turned off).
- **A drop onto empty playa hides the card**, header and all, because the card is removed
  from the hierarchy whenever it has no items. The marker's callout is then the only
  feedback. Showing an explicit "nothing within 100 m of …" state is a reasonable follow-up.

---

# Work Log — Global Search: Favorites, Event Time Filters, Results Index

## High-Level Plan

Four user-reported items on the global search screen (`iBurn/ListView/GlobalSearch*`),
which is hosted three ways: the classic nav-bar `UISearchController`, the map's
`MapBottomSearchController` overlay, and the iOS 26 `UISearchTab`.

1. **Favoriting from search did nothing** (day-one gap). Every row passed
   `isFavorite: false` and an empty `onFavoriteTap` to `ObjectRowView`, so the heart was
   permanently unfilled and inert.
2. **No way to narrow events by when they happen.** The filter sheet had only
   "Only Favorites" and "Happening Now".
3. **No quick-scroll index.** Long result sets had to be flicked through.
4. **The scope segmented control read badly** against the strip painted behind it.

## Item 1 — Favoriting from search

**Data.** Search results come from one-shot per-type fetches that return bare objects, not
the `ListRow`s the observation-backed list screens get, so nothing carried metadata. Rather
than adding four `ListRow` variants, one batched lookup was added to the data layer:

```swift
// Packages/PlayaDB/Sources/PlayaDB/PlayaDB.swift
func favoriteIdentifiers(among objects: [any DataObject]) async throws -> Set<String>
```

It returns *metadata identity* uids — the parent event's uid for an occurrence, the
object's own uid otherwise — collapsing several occurrences of one event to a single query
key. The implementation (`PlayaDBImpl`) groups by type and runs one indexed
`object_metadata` query per type present.

**View model.** `GlobalSearchViewModel` gained `favoriteIdentifiers: Set<String>`, refreshed
after every fetch (and after an AI merge), plus `isFavorite(_:)` / `toggleFavorite(_:)`.
`SearchResultItem` gained `dataObject` and `favoriteIdentity`.

**Why the optimistic flip.** Project convention is that view models backed by GRDB
observations do *not* optimistically mutate state — they let the stream deliver. This view
model is not observation-backed: it is one-shot fetches with no stream behind it, so
without an optimistic flip the heart would not change until the next search. The write is
still authoritative — the post-write `isFavorite` result is applied, a failure restores the
previous state, and every re-run of the search re-syncs the whole set from the database.

Legacy Yap mirroring goes through `FavoriteSyncService` exactly as the list screens'
data providers do, with the unsuffixed API uid for events.

**Accessibility fix (needed, and worth having).** `ObjectRowView`'s heart is an
`Image` + `onTapGesture` (deliberately, so it does not fight an outer row `Button`), which
left it out of the accessibility tree in *every* list screen — unreachable by VoiceOver and
untappable by UI automation. It is now an explicit accessibility element with the
`.isButton` trait and a "Favorite <name>" / "Unfavorite <name>" label, matching the
`NearbyCardView` convention.

## Item 2 — Day and time-of-day event filters

`GlobalSearchFilter` gained `day: Date?` and `timeOfDay: SearchTimeOfDay`
(`any` / `morning` 6–12 / `afternoon` 12–17 / `evening` 17–22 / `lateNight` 22–6).

- **Day** threads into `EventFilter.startDate`/`endDate` as calendar-day bounds, i.e. it
  narrows in SQL, matching `EventFilter.forDay(_:)`.
- **Time of day** is an hour-of-day predicate, which no single date range can express once
  "any day" is selected, so it is applied client-side to the already-fetched occurrences —
  **before** the one-row-per-event collapse. That ordering matters: an event running at
  both 9am and 11pm keeps its 11pm occurrence under "Late night" instead of being dropped
  because its earliest occurrence is a morning one. `lateNight` wraps midnight, so its
  membership test is a union of two ranges (`hour >= 22 || hour < 6`).
- Both surface through the existing filled-icon "filter is active" cue (they are part of
  `isDefault`), and both reset to "Any". They are disabled while "Happening Now" is on,
  which already pins the window to this moment.
- `GlobalSearchFilter` decodes field-by-field with defaults so a filter persisted by an
  older build restores instead of being discarded.

## Item 3 — Results index rail (Yap-style)

Originally built as a section-jump rail; reworked on feedback to reproduce the **original
Yap-based index**. `BRCDatabaseManager.registerSearchObjectsView` grouped searchable
objects two ways — non-events by uppercased first letter of the title (non-alphabetic into
`#`), events by `"yyyy-MM-dd HH"` in playa time — and `GroupTransformers.searchGroup`
rendered the event groups as a day initial plus a 12-hour clock hour ("M6"). Those group
names *were* the `sectionIndexTitles`: letters for camps/art/vehicles, numbers for events.

`SearchResultIndex` (pure, fully unit-tested) turns sections into rail entries:

- a **type marker** at the head of each section, using the app's existing iconography
  (`BRCArtIcon` / `BRCCampIcon` / `BRCEventIcon`; `car.fill` for vehicles, as the More
  screen uses). Markers are jump targets too.
- one stop per consecutive run of rows sharing an index title, anchored to the first row of
  the run, so scrubbing down never jumps backwards.
- a composed bubble label per stop — "Camps — B", "Events — Mon 9a" — since the rail glyph
  alone is too terse to tell you where you have landed.
- **crowding collapse**: when stops outnumber the available slots, type markers are kept
  whole and the letter/number stops between them are sampled evenly, with every other
  survivor drawn as a bullet. That is what `UITableView` does to a crowded index, and it is
  why the legacy screens could show a full A–Z on a small phone. Slot count comes from the
  rail's measured height.

The drag/haptics/measurement machinery is `EventHourIndexView`'s (PreferenceKey-measured
labels in a named coordinate space, `DragGesture(minimumDistance: 0)` nearest-label
hit-test, light impact per step, floating bubble). Rows reserve trailing room for the rail
so their text does not run underneath it.

Art/camps/vehicles are re-sorted with `localizedStandardCompare` in the view model: PlayaDB
returns them `orderedByName()`, but that is SQLite's binary collation, which sorts "Zoo"
before "aardvark" and would put a second "A" run below "Z". AI-merged results are re-sorted
into their section for the same reason.

## Item 4 — Scope bar chrome

The segmented control sat on a flat `.bar` strip, which on iOS 26 reads as a dirty band
across the top of the results. Removing the strip outright made the control unreadable over
scrolling rows, so the control now floats as **its own Liquid Glass element**
(`glassEffect(.regular, in: Capsule())`), inset from the screen edges and hung off
`safeAreaBar` rather than `safeAreaInset` so the system's scroll edge effect softens the
content passing underneath. Pre-26 keeps the arrangement that was already legible: a
material capsule where the bar floats over the map, the opaque strip where the list scrolls
under it. Both branches sit behind `canImport(FoundationModels)` as well as the availability
check, matching `NearbyCardView.GlassSurface`.

## Files

- `Packages/PlayaDB/Sources/PlayaDB/PlayaDB.swift`, `PlayaDBImpl.swift` — batch favorite lookup
- `iBurn/ListView/GlobalSearchScope.swift` — `SearchTimeOfDay`, day/time on `GlobalSearchFilter`
- `iBurn/ListView/GlobalSearchViewModel.swift` — favorites, event filter construction, dedupe, name sorting
- `iBurn/ListView/GlobalSearchView.swift` — live hearts, index rail host, scope bar chrome
- `iBurn/ListView/GlobalSearchFilterSheet.swift` — day + time-of-day pickers
- `iBurn/ListView/SearchResultIndexView.swift` — new; index model + rail view
- `iBurn/ListView/SearchResultItem.swift` — `dataObject`, `favoriteIdentity`, `startDate`
- `iBurn/ListView/ObjectRowView.swift` — favorite heart accessibility
- `iBurnTests/GlobalSearchFilterTests.swift` — new; pure-logic coverage
- `iBurnTests/GlobalSearchViewModelTests.swift` — favorites + day/time integration

## Outcomes

- iBurnTests: 411 passing (baseline 353), zero failures.
- Clean builds on iOS 26.5 (iPhone 17 Pro Max) and iOS 18.6 (iPhone 16 Pro Max).
- Simulator pass on the iOS 26 search-tab host: heart fills instantly and the favorite
  appears in the Favorites screen; the event favorite shows on every occurrence of that
  event; the day filter shifts results from Monday to Wednesday; "Late night" empties a
  morning-only query while "Morning" restores it; the rail renders icons + letters +
  event stops and scrubbing jumps between them.

## Caveats / Follow-ups

- Event index stops use the legacy day-initial + hour format ("M6"). If bare hour digits
  are preferred, it is a one-line change in `SearchResultIndex.eventTitle(for:)`.
- The bubble is only visible while a drag is in progress, so it cannot be captured by a
  screenshot taken after the gesture completes.
- Making the heart an accessibility element changes the AX tree of every `ObjectRowView`
  list, not just search. Existing automation that looked for the raw "Love" symbol image
  should prefer the new "Favorite <name>" button.

---

# Work Log — Drop-the-man feedback: real Man glyph + card visibility rules

## High-Level Plan

Two pieces of user feedback on the just-shipped long-press "drop the person" feature:

1. The marker drew an SF Symbol person. The app already ships the Burning Man **Man**
   artwork for the map's center pin; use that instead.
2. With the nearby card previously hidden (its "Hide" button persists
   `userInterface.nearbyCard.enabled = false`), dropping the marker put a pin on the map
   and **nothing else** — the card that was supposed to answer "what's over there" never
   appeared. And hiding the card *while* a marker was down cleared the drop **and** wrote
   the preference off, so a "check out that other spot" gesture silently turned off the
   user's own "what's near me" card.

Fixes: draw the Man; make card visibility `cardEnabled || overrideActive` (a transient
show, nothing written); and scope the hide button to the drop while one is active.

## Technical Details

### Man glyph — `iBurn/Map/DroppedPersonAnnotation.swift`

`DroppedPersonMarker` keeps its chip construction (34 pt circle, 2.5 pt white ring, drop
shadow, blue face) and swaps only the figure. The artwork is the existing
`pin_center` imageset, which is **appearance-scoped** (black for light, white for dark)
rather than template-configured, so the marker asks for the dark variant explicitly and
re-tints it anyway:

```swift
static func makeGlyph() -> UIImage? {
    let darkTraits = UITraitCollection(userInterfaceStyle: .dark)
    if let asset = UIImage(named: glyphAssetName, in: nil, compatibleWith: darkTraits) {
        return asset.withTintColor(.white, renderingMode: .alwaysOriginal)
    }
    // …SF Symbol fallback so a catalog miss degrades to a person, not an empty chip
}
```

`withTintColor` treats the artwork as an alpha mask, so the glyph is crisp white whichever
variant the catalog resolves. It is drawn at its own aspect ratio (the artwork is 1000×950,
i.e. a touch wider than tall) at **20 pt tall** inside the chip's 29 pt face. The nearby
card's header line uses the same asset, template-rendered at 11 pt in the card's secondary
color, so the header and the marker match.

### Visibility + hide rules — `iBurn/Map/NearbyCard/NearbyCardPreferences.swift`

Two pure functions over the only two inputs that matter, plus the outcome type:

```swift
enum NearbyCardHideAction: Equatable { case clearDroppedPin, disableCard }

enum NearbyCardVisibility {
    static func isVisible(cardEnabled: Bool, overrideActive: Bool) -> Bool {
        cardEnabled || overrideActive
    }
    static func hideAction(overrideActive: Bool) -> NearbyCardHideAction {
        overrideActive ? .clearDroppedPin : .disableCard
    }
}
```

- `NearbyCardViewModel.isCardVisible` wraps the first, and `rebuildItems()` now gates on it
  instead of the raw preference — so a drop repopulates `items` (and therefore the card,
  which is removed from the hierarchy when `items` is empty) regardless of the setting.
- `NearbyCardViewModel.hide()` performs the second and returns what it did. The hosting
  controller shrank to `onCardHidden?(viewModel.hide())`, and `MainMapViewController` now
  raises the "turn it back on in Map Filter" tooltip only for `.disableCard`.
- `NearbyCardView`'s footer button is relabelled while a drop is active: **"Hide"** →
  **"Clear pin"** (AX "Clear dropped pin", hint "Puts the card back on your own location").

### Design call — what "Hide" means while a pin is down

Considered: (a) always make the card disappear, persisting only in the non-dropped case —
which needs a third "transiently hidden" state and makes a labelled "Hide" mean two
different durations; (b) scope the button to the drop. Chose **(b)**, with the relabel as
the thing that keeps it honest — a button that says "Hide" and doesn't hide would be the
surprising outcome, but one that says "Clear pin" and clears the pin is not. Net behavior:

| stored pref | pin down | card on screen | press the footer button      |
|-------------|----------|----------------|------------------------------|
| on          | no       | yes            | card off, preference written |
| on          | yes      | yes            | pin cleared, card stays      |
| off         | no       | no             | (no card, no button)         |
| off         | yes      | yes (transient)| pin cleared, card hides again|

The invariant: **the persisted preference changes only when the card is hidden in its
normal, device-sourced state.**

## Tests — `iBurnTests/DroppedPinSourceOverrideTests.swift`

Added an `ObservablePreferenceService` double (`CurrentValueSubject` per key — the existing
`Just`-based in-memory double can't deliver a change, and the card *observes* its preference),
and the card view model helper now takes an injected preference store so nothing depends on
the host app's defaults. New cases: the full `isVisible` truth table; `hideAction` both ways;
drop-shows-a-hidden-card (and writes nothing); pin-down hide leaves the preference on; hide
from the transient state just removes the pin; hide with no pin is the one that persists;
re-enabling from Map Filter brings the card back; plus two marker cases (the `pin_center`
asset resolves in the app bundle, and the chip image is round, shadow-padded and
`.alwaysOriginal`).

## Simulator validation (iPhone 17 Pro Max, iOS 26.5)

- Long-press a camp pin → white Man on a blue chip, legible at map zoom
  (`/tmp/claude/iburn-polish-round/A1-man-glyph-zoom.png`), header "Nearby 9:23 & Great Oak"
  with the matching glyph, card content re-sourced to Snuggles.
- "Clear pin" with the preference on → pin gone, card returns to device content (Aeshtah),
  no tooltip. "Hide" with no pin → card gone + tooltip, preference reads `0`.
- With the preference at `0`: drop → the card appears with dropped content, preference still
  reads `0`; callout ⊗ "Remove dropped pin" → card disappears again; relaunch → no marker,
  no card; Map Filter → "Show Nearby Card" → Done → normal card back.

---

# Work Log — Detail map zoom: fit user + POI, or POI + Man off playa

## High-Level Plan

Tapping a modern art/camp/event detail screen's map pushed `MapListViewController`, whose
`viewDidAppear` fit **only the annotation coordinates** at 10 pt padding. With one annotation
that is a maximum zoom onto a single dot surrounded by nothing. The legacy path
(`MLNMapView.brc_showDestination`) had always done it right — second point = the user when
inside `BRCLocations.burningManRegion`, else the Man — so the fix is to extract that rule and
share it.

## Technical Details

### `iBurn/BRCLocations.swift` — the rule, in one place

```swift
@objc static func mapFramingCoordinate(forUserLocation location: CLLocation?) -> CLLocationCoordinate2D {
    guard let coordinate = location?.coordinate,
          CLLocationCoordinate2DIsValid(coordinate),
          burningManRegion.contains(coordinate) else {
        return blackRockCityCenter
    }
    return coordinate
}
```

### `iBurn/MLNMapView+iBurn.m` — now calls it (no behavior change)

The three-step dance (default to the city center, take the user coordinate if valid, fall
back if outside the region) collapses to one call. Same result for every input.

### `iBurn/MapListViewController.swift` — the two-point fit

`viewDidAppear` now filters out `MLNUserLocation` (the map's own annotation, which must not
count towards "how many pins am I showing") and invalid coordinates, bails on an empty set,
and branches:

- exactly one coordinate → append `mapFramingCoordinate(forUserLocation:)` and fit with
  `top 120 / left 60 / bottom 45 / right 60` — generous at the top because the navigation bar
  overlaps the map (`edgesForExtendedLayout` is `.all`), where `brc_showDestination`'s callers
  pass a flat 45 pt box for a map that isn't under one;
- two or more → unchanged: annotations only, 10 pt padding.

`animated` is still passed straight through.

## Tests — `iBurnTests/MapFramingCoordinateTests.swift` (new)

Six cases over the extracted rule: inside the region (deep playa, standing on the Man, a
couple of miles out) returns the user's coordinate; outside (a distant city, ~50 miles out)
returns the Man; `nil` and an invalid coordinate return the Man. Each off-playa fixture
asserts its own precondition against `burningManRegion` so a future region change fails
loudly rather than silently passing for the wrong reason.

## Simulator validation (iPhone 17 Pro Max, iOS 26.5)

- `simctl location set 40.7930,-119.1960` (deep playa) → camp detail → tap map: the camera
  frames the POI pin *and* the orange user dot
  (`/tmp/claude/iburn-polish-round/B1b-onplaya-deep-playa-user-and-poi.png`).
- `set 37.77,-122.41` (off playa) → same flow: the frame stretches from the POI to the Man
  at city scale (`B2-offplaya-fits-poi-and-man.png`).
- Nearby → "Show Map" (≈30 pins) is unchanged — tight fit around the cluster
  (`B3-multipin-unchanged.png`).

## Outcomes (both items)

- iBurnTests: **428 passing** (baseline 411), zero failures.
- Clean builds on iOS 26.5 (iPhone 17 Pro Max) and iOS 18.6 (iPhone 16 Pro Max).

## Caveats / Follow-ups

- The single-annotation branch keys off the annotation **count**, not off who pushed the
  screen. A future list that legitimately pushes exactly one pin would also get the
  two-point fit — which is arguably right, but it is a heuristic, not an intent.
- If the user is standing essentially on top of the POI, the two-point fit degenerates to a
  near-maximum zoom. `brc_showDestination` has always had the same property.
- The Man glyph is drawn from an appearance-scoped imageset. If `pin_center` is ever
  reorganized into a template asset, the explicit dark-variant lookup becomes redundant but
  stays harmless; the unit test guards the name itself.

---

# Session 3 (2026-08-09, later): six small fixes

## High-Level Plan

A bundle of six independent, small user-facing fixes on `2026-updates` (from `6eecd11`).
Nothing here shares code with anything else in the bundle except items 5 and 6, which both
land on the floating action button.

1. Hide the global-search "finding more with AI" pass — it doesn't return useful results.
2. Re-tapping the Map tab resets the map (the behavior the legacy app had, dead since the
   `UITab` layout landed).
3. Always show the user's compass heading on the map puck.
4. Bike/home/star pins land at the viewport center when the user is off playa.
5. The FAB glyph should read as an unselected tab item, not as the accent.
6. Whimsy: the FAB glows when a favorite is added anywhere.

## Technical Details

### 1. AI search behind a feature flag

- `iBurn/Preferences/Preferences.swift` — new `Preferences.FeatureFlags.useAISearch`
  (`featureFlag.search.useAI`), **default false**.
- `iBurn/ListView/GlobalSearchViewModel.swift` — the flag is snapshotted into a new
  `isAISearchFlagEnabled` init parameter (defaulting to the preference) and ANDed into
  `isAISearchAvailable`. Gating there rather than at the call site is what turns off the
  fetch, the "Finding more with AI…" spinner row, *and* the per-row `sparkles` badge in one
  place: with the flag down `runAISearch` never runs, so `isAISearching` stays false and
  `aiSuggestedUIDs` stays empty. Nothing was deleted — `AISearchService`,
  `runAISearch`, `mergeAIResults` and the SwiftUI row are all intact.
- The parameter (rather than reading the preference inside the getter) exists so the three
  existing AI tests can force the feature on without writing to the shared defaults the app
  reads; two new tests cover the off state.
- `iBurn/Preferences/FeatureFlagsView.swift` — "AI Search Merge" toggle in the DEBUG screen.

### 2. Map tab re-tap → pop, then recenter

The legacy implementation lived in `BRCAppDelegate`'s
`tabBarController:didSelectViewController:` (added in `9b432f7`, 2014). That callback only
fires in classic `viewControllers` mode, so the behavior had been silently dead on the iOS 26
`.searchTab` layout, which drives selection through `UITab`.

- **New** `iBurn/Tabs/MapTabReselection.swift` — a pure
  `outcome(selected:isAlreadySelected:navigationStackDepth:) -> .ignore | .popToRoot | .recenter`.
  Stock iOS re-tap semantics: pop first if anything is pushed, recenter only once the map
  itself is on screen. Switching *to* Map from another tab does neither.
- `iBurn/TabController.swift` — `TabController` is now its own `UITabBarControllerDelegate`
  (set in `configure(withRootViewControllers:)`) and implements **both**
  `shouldSelect(viewController:)` (classic) and `shouldSelectTab:` (iOS 18+). A stored
  `usesSearchTab`, written by `rebuildTabs()`, routes each tap to exactly one of them so a
  single tap can't be handled twice. `shouldSelect*` rather than `didSelect*` because only
  the former is guaranteed to be asked when the tap doesn't change the selection — which is
  the entire case being handled. Recenter calls the same
  `centerMapAtManCoordinatesAnimated(true)` the legacy path did
  (`BRCLocations.blackRockCityCenter`, zoom 13).
- `iBurn/Tabs/TabIdentifier.swift` — `identifier(forTabIdentifier:)`, the reverse of
  `tabIdentifier`, so the `UITab` callback can name the tab it was handed.
- `iBurn/BRCAppDelegate.{h,m}` — dropped `UITabBarControllerDelegate` conformance, the
  `self.tabBarController.delegate = self` assignment, and the legacy handler.

### 3. `showsUserHeadingIndicator`

`iBurn/MLNMapView+iBurn.swift`, one line in `brc_setDefaults` next to `showsUserLocation`.
MapLibre documents the property as *not* rotating the camera and as a no-op in the
follow-with-heading/course modes that draw their own arrow, so tracking mode is untouched.
One-line revert if it's unwanted.

### 4. Off-playa pin placement → viewport center

- `iBurn/BRCLocations.swift` — new
  `userMapPointCoordinate(forUserLocation:viewportCenter:)`, same 5-mile `burningManRegion`
  test as `mapFramingCoordinate(forUserLocation:)` from `6eecd11`, different fallback. The
  two rules are deliberately separate functions rather than one parameterized one: framing a
  destination wants the Man (context), placing a pin wants the screen (reachability).
- `iBurn/MainMapViewController.swift` — `addUserMapPoint(type:)` now passes
  `mapView.centerCoordinate` as the fallback, replacing the old
  `BRCLocations.blackRockCityCenter`. The viewport center is used unconditionally when off
  playa: whatever is centered on screen is by definition visible and draggable.

### 5. FAB glyph color

`iBurn/Tabs/FloatingActionButton.swift` — `applyTheme()` moved the glyph from
`primaryColor` (the accent, i.e. what the bar uses to mean *selected*) to
`secondaryColor` (`.label`).

**Not** `detailColor`, which is what `Appearance.applyTabBarAppearance` nominally assigns to
`unselectedItemTintColor` and to every `normal.iconColor`. The iOS 26 floating bar — the only
layout the FAB exists on — ignores that appearance and draws its unselected items in `label`.
Sampled from a shipped screenshot: every unselected bar glyph, including the search circle
directly below the button, is `#1E1813`; `detailColor`/`.secondaryLabel` renders `#888689`
and reads as disabled beside them. On iOS 18.x the appearance *is* honored (unselected items
render gray), but the FAB never appears there, so matching the 26 bar is the whole job.

### 6. FAB glow on favorite-added

**Seam chosen: `PlayaDBImpl.toggleFavorite`.** The brief preferred an app-level seam, and
there isn't one — the per-type `ObjectListDataProvider`s cover only the browse lists, while
Detail, Right Now, Nearby, the map's visible-pins sheet, Recently Viewed, Visits and global
search all call `PlayaDB.toggleFavorite` directly (~30 call sites across 32 files).
`FavoriteSyncService.mirrorFavorite` is downstream, explicitly non-authoritative, and invoked
separately by each caller, so it's neither complete nor the right layer. `PlayaDBImpl` is the
single point everything passes through.

- **New** `Packages/PlayaDB/Sources/PlayaDB/FavoriteChangeNotification.swift` —
  `Notification.Name.playaDBFavoriteDidChange` plus a `PlayaDBFavoriteChange` namespace for
  the `userInfo` keys and an `isFavorite(from:)` reader.
- `Packages/PlayaDB/Sources/PlayaDB/PlayaDBImpl.swift` — `toggleFavorite` now returns the
  resulting state out of the GRDB write and posts on the main queue. **`setFavorite` does
  not post** — that's how watch sync and merges write, and those aren't a person tapping a
  heart.
- `iBurn/Tabs/FloatingActionButton.swift` — `FloatingActionButtonGlow.shouldGlow(
  isVisible:action:favoriteWasAdded:)` (pure, mirroring `FloatingActionButtonVisibility`'s
  shape) and `playFavoriteAddedGlow()`: ~0.75s, a 1.12× scale pulse with a spring settle plus
  an accent halo (a `glow` subview behind the glass, `shadowRadius` 16, peak alpha 0.55)
  blooming to 1.45× and fading. Under `UIAccessibility.isReduceMotionEnabled` nothing scales
  and only the halo fades in and out.
- `iBurn/TabController.swift` — observes the notification and runs the rule.

**Eligibility choice: Favorites-only.** The glow says "your favorite landed *in here*", which
only parses if the button is the door to Favorites; a halo on a calendar glyph after
favoriting a camp is a promise the button doesn't keep. So it fires on
**visible && added && action == .favorites** — never on removal, never for an
Events/Nearby-configured button, and nothing is queued for a button that was off screen.

## Tests

New: `iBurnTests/MapTabReselectionTests.swift` (10 — including the pop-then-recenter
sequence and the `TabIdentifier` string round trip), `iBurnTests/UserMapPointCoordinateTests.swift`
(10 — on playa, off playa, invalid/no fix, and a case pinning the divergence from
`mapFramingCoordinate`), 4 glow-eligibility tests in `TabConfigurationTests.swift`, 2 AI
flag-off tests in `GlobalSearchViewModelTests.swift`.

- **iBurnTests: 453 passing** (baseline 428), zero failures.
- **PlayaDB package: 262 passing**, zero failures (pre-existing Swift 6 capture warnings).
- Clean builds on iOS 26.5 (iPhone 17 Pro Max) and iOS 18.6 (iPhone 16 Pro Max, by UDID).

## Simulator validation (iPhone 17 Pro Max iOS 26.5, plus iPhone 16 Pro Max iOS 18.6)

Screenshots in `$TMPDIR/iburn-shots/`:

| Item | Evidence |
| --- | --- |
| 1 | `01-search-no-ai-row.png` — "yoga" results, no spinner row, no sparkles badges |
| 2 | `02a-map-panned-away.png` → `02b-map-recentered-after-retap.png`; plus a `screenHash` trace: panned `06981ga` → push List → re-tap → `06981ga` (popped, *not* recentered) → re-tap → `0gpomy0` (centered). Repeated on the 18.6 classic bar: `11t7jsp` → push → re-tap → `11t7jsp` → re-tap → recentered |
| 3 | `03-user-puck-zoom.png` — puck renders; **no arrow, because the simulator delivers no compass heading**. Unverifiable in the sim by construction |
| 4 | `04b-pin-at-viewport-center.png` — GPS at 37.77,-122.41, map panned, "Drop a pin" → star lands dead center |
| 5 | `05-fab-vs-tabs.png` — heart matches the search magnifier and the Nearby/Events/More glyphs; only the selected Map tab is orange. Sampled: FAB `#000000`, search circle / unselected tabs `#1E1813`, selected Map `#D17900` |
| 6 | `06-fab-glow-real.png` — four consecutive frames through the bloom. Per-frame mean HSB saturation over a crop of the FAB: baseline ≈0.039, glow peak 0.494 across ~4 frames (~0.75s at the capture rate); the *un*favorite tap earlier in the same capture shows no spike at all |

Capture note: `simctl recordVideo` mangles colors badly enough to be useless for judging a
tint. The reliable technique is a background `for i in $(seq 200); do xcrun simctl io <UDID>
screenshot …; done` loop, tap, then rank frames by saturation over a crop.

## Docs updated

`.claude/skills/drive-app/references/flows.md` — §5 (AI merge is flag-off), §6 (map re-tap,
heading indicator, off-playa pin placement), §8 (new debug toggle), §8a (FAB glyph color,
the glow and how to catch it).

## Caveats / Follow-ups

- **Item 3 is unverified on real hardware.** The simulator has no heading, so only a device
  can confirm the arrow renders and that it doesn't rotate the camera in practice. One-line
  revert (`showsUserHeadingIndicator` in `brc_setDefaults`) if it misbehaves.
- **The favorite notification lives in the PlayaDB package**, against the preference for an
  app-level seam, because no app-level seam sees every toggle. If one is ever introduced
  (e.g. every screen routing through a single app-side favorites service), the post should
  move there and the package should go back to being UI-agnostic.
- **Glow intensity is a single constant** — the halo's peak alpha (0.55) in
  `playFavoriteAddedGlow()`. It reads strong against the dark, image-themed list rows and
  softer over the map; dial it there if it wants to be quieter.
- **`brc_setDefaults` applies to every map**, so the heading indicator is on detail maps too.
  That seems right (same puck, same question) but it wasn't asked for explicitly.
- The AI flag is snapshotted at view-model construction, so toggling it in the debug screen
  needs search to be reopened — noted in the toggle's footer and in flows.md.
