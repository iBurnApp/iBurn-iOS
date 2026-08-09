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

**Open decision (user):** commit `8f2112e`'s *message* in the private repo names the data sender, the distribution channel, and the extraction tool. File contents are all sanitized (`4908585` covered the last two references, in the data repo's `CLAUDE.md` and `mock_locations.js`), but scrubbing the commit message itself means rewriting pushed history on the private `2026-updates` branch — not done without authorization. Must be decided before the private branch is mirrored to the public repo at gates-open; alternatives are a reworded rebase + force push (clean), or mirroring via a squashed/grafted publish instead of a direct branch push.

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
