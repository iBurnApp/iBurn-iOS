# 2026-07-25 — Geocoder on BMorg's official GeoJSON (both directions)

## High-Level Plan

**Goal** (branch `reverse-geocoder`): make the org's official map GeoJSON
(`bmorg/innovate-GIS-data`) the source of truth for all geo operations, in both
directions — the API data pipeline geocodes camp GPS from playa addresses, so
forward matters as much as reverse — keeping the shared-JS-bundle shape that
lets iOS and Android run the same implementation.

**Phase 1 — audit + verify the legacy geocoder against 2026. Done.** Found and
fixed an `undefined` street bug; corrected two wrong street facts (below); added
2026 regression coverage where the suite had been pinned to 2025 fixtures.

**Phase 2 — org-GeoJSON geocoder, forward and reverse. Done and shipped.**
`src/orggeocoder/` now backs the data pipeline and the apps' `bundle.js`.
Native Swift/Kotlin ports remain the endgame; the conformance sweep built here
is their shared test vector.

## Audit findings (how geocoding works today)

- **One JS artifact serves both apps.** `BlackRockCityPlanner/src/geocoder/index.js`
  hardcodes `require('../../../../data/<YEAR>/layouts/layout.json')`; browserify
  inlines the layout into `data/<YEAR>/geocoder/bundle.js`. `prepare()`
  synthesizes every polygon/street **in memory from layout.json at startup** —
  the geocoder never reads the generated `geo/*.geojson`.
  - iOS: `PlayaGeocoder/PlayaGeocoder.swift` (JavaScriptCore, serial queue),
    bundle path pinned at `PlayaGeocoder.xcodeproj/project.pbxproj:46` →
    `data/2026/geocoder/bundle.js`. Already on 2026.
  - Android: `iBurn/src/main/java/com/gaiagps/iburn/js/Geocoder.kt` (J2V8) runs
    `iBurn/src/main/assets/js/bundle.js` — **still the 2025 build** (embeds
    `data/2025/layouts/layout.json`, none of the 2026 street names).
- iOS call sites: 9 total — sync (blocking) reverse in `BRCMapPoint.m:209`,
  `TracksViewController.swift:145`, `BRCDataImporter.m:330/446`; async nav-bar
  address in map/list controllers on a 5 s timer; forward geocoding only at
  import (`BRCDataImporter.m:335-341`). Watch app has no geocoding at all.
- `Packages/PlayaGeo` (watch map renderer) already loads `data/2026/geo/*.geojson`
  and has the equirectangular projection — natural home for a Swift port
  (per `Docs/2026-07-07-architecture-analysis-and-roadmap.md` L270-272).
- `data/2026/geo/*` was freshly generated Jul 3 from the 2026 layout; its only
  consumer is the watch app (tiles now come from BMorg data).
- This worktree's `Submodules/iBurn-Data` was an unpopulated stale pointer;
  synced it from the sibling clone (`git fetch <local path>` + checkout
  `c9f7bdb`, nested submodules via `-c protocol.file.allow=always`).

## 2026 layout verification (vs BMorg innovate-GIS-data @ e9e33e0)

- `data/2026/layouts/layout.json` is **current** apart from the C-street name
  corrected below: 12 themed names (Esplanade, Ararat, Bodhi, **Ceiba**, Delphi,
  Eternal, Fulcrum, Great Oak, Heiau, Iroko, Jiba, Kundalini), center `[-119.207871, 40.783242]` matches
  `YearSettings.plist` and org's "The Man" CPN within 4'. Ring radii match org
  annular centerlines within ~3' on all 12 rings. New 2:15/9:45 F–I segments and
  the two new B plazas (2:00/10:00) are modeled.
- **Validation sweep**: intersected every org radial × annular centerline
  (`turf.lineIntersect`, letters mapped to themed names) → **512 ground-truth
  points**, reverse geocoded each with the legacy geocoder:
  - **Clock times: 512/512 within 3 minutes** (most exact).
  - Street names exact except two benign classes:
    1. *Ring-edge epsilon (~25', half a road width)*: points exactly on the
       Kundalini or Esplanade centerline can fall just outside the streets-area
       polygon → `5:00 & 5760' Outer Playa` instead of `5:00 & Kundalini`
       (correct time, distance = ring radius). Below GPS accuracy; documented
       in the new test file, not "fixed".
    2. *Center Camp overlap*: org draws A/B rings schematically through Center
       Camp; legacy correctly answers `Café` / `Center Camp Plaza` there.
- POI check: `poi.json` (2025 carryover) is all time/distance-relative, so
  positions track the moved Golden Spike automatically; Center Camp Plaza and
  The Man within 2–4' of org CPNs.

## Bug found + fixed: `"6:26 & undefined"` near Center Camp

2026 (and 2025) layouts have no `rod_road_distance`, so the `frontage_arc` is
the Center Camp boundary street — and it reached the reverse candidate set with
`name: undefined`. Any GPS point nearest that arc produced `"<time> & undefined"`.

**Correction (same session):** an initial pass named that arc "Rod's Road",
reasoning from `Rods Road` features in the 2026 GIS drop. That was wrong —
**BMorg removed Rod's Road for 2026**; those features are carryover the org
left in the data. The fix that stands is the general one: `reverse.js` drops
unnamed streets from the candidate set, so the arc degrades to the nearest
real named street instead of emitting `undefined`, and `Rods Road`/`Route 66`
are listed as `retired_streets` in the new geocoder config.

**Also corrected: the C street is `Ceiba`, not `Chomolungma`.** Both official
sources (the April 2026 street-name announcement in the Burning Man Journal and
the current [2026 BRC Plan page](https://burningman.org/black-rock-city/black-rock-city-2026/2026-black-rock-city-plan/))
name it Ceiba. The wrong name had been baked into `layout.json`, the geocoder
bundle, **and the shipped map tile labels** — all three regenerated.

## New tests (`BlackRockCityPlanner/tests/Geocoder2026Test.js` + `layout2026.json`)

43 assertions, all passing; full suite 17/17 green (coverage gates intact):
- 12 org-derived intersection literals (one per ring; Esplanade/Kundalini nudged
  20' off the epsilon band, commented as such).
- Landmarks: Man → `0' Inner Playa`, Center Camp center → `Café`, 6:00
  promenade → Inner Playa, far away → `Outside Black Rock City`.
- Center Camp frontage arc: points near it resolve to real named streets,
  never `undefined` and never a retired name.
- **No-undefined sweep**: 0.002° grid over the whole city + margin.
- Forward: all 12 themed streets at 6:30 land at their layout ring distance
  (±10'); new 2:00/10:00 B Plazas resolve near the B ring; 4 forward↔reverse
  round trips.

## Phase 2 (built this session): org GeoJSON as source of truth

`BlackRockCityPlanner/src/orggeocoder/` — a geocoder whose inputs are BMorg's
official GeoJSON, replacing the synthesize-the-city-from-layout.json approach in
**both** directions (the API pipeline geocodes camp GPS from playa addresses, so
forward mattered as much as reverse).

### What the org data provides vs. what still needs config

Official: street centerlines with widths, plaza polygons, 59 named CPNs, trash
fence, city blocks, DMZ, toilets. **Not** in the GIS drop, so it lives in
`data/<year>/geocoder/config.json` (~20 lines): the letter → themed street-name
map, the city bearing, retired streets, and which CPN names the Center Camp
keyhole.

### Year-to-year schema drift (the reason `schema.js` exists)

BMorg changes the shape of the drop between years, so every property read goes
through an adapter:

| | 2024 / 2025 | 2026 |
|---|---|---|
| street class | `type: arc\|radial` | `source: annular\|radial\|center_camp` |
| width | `width` | `width_ft` |
| ring names | themed (`Kilgore`) | letters (`K`) |
| plaza name key | `Name` | `name` |

They also disagree with themselves: the 2025 GIS says `Jemison`, the street
announcement says `Jemisin`. `prepare.js` binds rings to config letters through
a near-spelling match and prefers the announced spelling.

### Algorithm

- **Reverse**: outside trash fence → `Outside Black Rock City`; inside a plaza
  polygon → that plaza's official name; within the street band (innermost to
  outermost ring covering this bearing, ± half a road width) → nearest ring, as
  `<time> & <street>`; else open playa → `<time> & <feet>' Inner|Outer Playa`.
  Each ring's radius is **sampled from its real centerline at the point's
  bearing**, which is what kills the legacy epsilon band.
- **Interior gaps**: Esplanade has a real 5:45–6:15 gap (the Center Camp
  keyhole). Points there are neither street nor open playa, so they resolve to
  the configured landmark (`Center Camp`). The rule is scoped to bearings where
  other rings exist, so deep playa is unaffected.
- **Forward**: street intersections (letters and themed names interchangeable),
  time+distance, plaza perimeters, portals, named landmarks. A named ring always
  wins over a portal, so `"3:00 Portal & A"` is the A-street intersection while
  `"9:00 Portal"` is the CPN.

### Validation

- **Reverse conformance**: all **512** intersections of official radial × ring
  centerlines → 489 exact, 23 correctly naming the plaza sitting on the
  intersection, **0 wrong**. Legacy: 44 wrong-street + 4 misclassified.
- **Forward vs published GPS**: all **1369** published 2025 camp addresses
  resolve (legacy fails 30), **median 7'**, 98% within 150'. Note the published
  coordinates were themselves produced by the legacy geocoder, so this measures
  agreement, not independent truth; the tail is portals, where the org CPN is
  surveyed truth and legacy's position was computed.
- **Parity sweep**, 2773-point city grid: 95.6% identical or within 5'. The 123
  remaining differences all favor org data — 20 streets legacy put in open playa,
  6 points outside the real fence, 5 plaza/Center Camp namings, and ~92 one-minute
  clock/1-foot distance shifts from the 4' difference between the layout center
  and the official `The Man` CPN.
- **Engines**: verified through real JavaScriptCore (47ms setup) and through
  Android's exact call pattern (`window.prepare()` / `coder.reverse` /
  `coder.forward` / `forwardAsString`).
- Bundle is **868KB preparing in 13ms**, vs 1.2MB / 36ms for the legacy bundle.

### Wiring

`factory.js` gives the CLI tools an org-backed geocoder when the year has GIS
data and the legacy one otherwise, inferring year and checkout root from the
existing `--layout` path — so `fetch_and_geocode.js`, `api.js`,
`mock_locations.js` and `generate_all.js` are all on org data with **no change to
documented commands**. `generate_all`'s POIs moved ≤4' and The Man now lands
exactly on its official CPN.

Bundle build is now two steps (browserify can't require `.geojson`):

```bash
node src/cli/build_geocoder_data.js --data-root ../../ --year 2026 \
  --output ../../data/2026/geocoder/geocoder-data.json
browserify src/orggeocoder/index.js -o ../../data/2026/geocoder/bundle.js
```

The year is hardcoded in exactly one place now (`src/orggeocoder/index.js`),
down from two.

### Native ports (still the endgame)

The org geocoder needs only bearing, haversine distance, point-in-polygon and a
sorted-sample lookup — no turf/JSTS. That makes the Swift port into `PlayaGeo`
(watchOS support, no JSContext startup cost behind the three blocking iOS call
sites) and a matching Kotlin port straightforward, with
`tests/OrgGeocoderTest.js`'s 512-intersection sweep as the shared conformance
vector.

## Remaining work / follow-ups

- [x] Org-GeoJSON geocoder, both directions, wired into the pipeline and shipped
      as the apps' `bundle.js`.
- [x] Android bundle refreshed (it had still been the **2025** build).
- [x] Commits mirrored to the main `iBurn-iOS` checkout.
- [ ] **Android commit not made** — `iBurn-Android` has the new
      `assets/js/bundle.js` in its working tree, left for review.
- [ ] Full `iBurn` app build not run **in this worktree**: it has no `Pods/`
      installed (pre-existing). The `PlayaGeocoder (iOS)` framework builds clean
      and embeds the new bundle; verify the app target from the main checkout.
- [ ] POI sourcing: `poi.json` still places Greeters/Airport by time+distance,
      landing 263'/700' from their official CPNs. Sourcing those from
      `cpns.geojson` would finish the job.
- [ ] `data/<year>/geo/*.geojson` (watch map renderer) is still generated from
      `layout.json`. Pointing `PlayaGeo` at org GeoJSON would retire the
      handcrafted layout entirely; `layout.json` is then only needed for years
      before the GIS drops.
- [ ] Swift + Kotlin native ports of the org reverse geocoder.

## Cross-References

- `Docs/2026-07-25-bmorg-geojson-refresh-gate-road.md` — same-day tile refresh.
- `Docs/2026-07-13-official-2026-map-tiles.md` — org-data tile migration, rename script.
- `Docs/2026-07-07-architecture-analysis-and-roadmap.md` L137/270 — PlayaGeo absorption plan.
- `Docs/2026-07-03-2026-year-update-plan.md` — the stale-2025-bundle shipping bug.
- iBurn-Data `Docs/2025-07-19-map-tiles-official-data.md`; planner
  `Docs/2025-08-21-fix-distance-multiplication.md` (turf v7 `{units:}` regression).

## Expected Outcomes

- Reverse geocoding for 2026 validated against BMorg's official geometry; no
  more `undefined` street names near Center Camp; Rod's Road addresses match
  the official map.
- Any future layout with unnamed streets degrades gracefully instead of
  emitting `undefined`.
- 2026 regression coverage exists (previous suite was pinned to 2025 fixtures).
- Clear, phased path to an org-GeoJSON-native cross-platform reverse geocoder.
