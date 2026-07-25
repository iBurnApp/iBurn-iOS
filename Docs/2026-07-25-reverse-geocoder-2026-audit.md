# 2026-07-25 — Reverse geocoder: 2026 verification + org-GeoJSON feasibility

## High-Level Plan

**Goal** (branch `reverse-geocoder`): a reverse geocoder whose source of truth is
the org's official map GeoJSON (`bmorg/innovate-GIS-data`), built so the same
approach works on Android like today's shared JS geocoder.

**Phase 1 (this session)**: audit + verify the handcrafted layout / legacy
geocoder against the 2026 street layout, fix what's broken, and land 2026 test
coverage. **Done.**

**Phase 2 (next)**: org-GeoJSON-driven reverse geocoder — feasibility assessed
below, recommended architecture: twin native ports (Swift in `PlayaGeo`,
Kotlin on Android) sharing an org-data-derived conformance test-vector file.

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

- `data/2026/layouts/layout.json` is **current**: all 12 themed names
  (Esplanade, Ararat, Bodhi, Chomolungma, Delphi, Eternal, Fulcrum, Great Oak,
  Heiau, Iroko, Jiba, Kundalini), center `[-119.207871, 40.783242]` matches
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

Org data proves the frontage arc **is Rod's Road in 2026**: org `Rods Road` is
6 segments at ~777' from Center Camp center covering true bearings ~327°→123°;
the layout `frontage_arc` is the 783' centerline over 329°→121° (45°+284°→45°+76°).
(Org `Route 66` is a separate inner service road at ~490'; not modeled, fine.)

**Changes** (BlackRockCityPlanner `7a8ae48`, iBurn-Data `f8911da`):
- `data/2026/layouts/layout.json`: `frontage_arc.name = "Rod's Road"`.
- `src/centercampstreetplanner.js` `getFrontageRoad()`: emit optional
  `frontage_arc.name`.
- `src/geocoder/reverse.js`: candidate filter now requires `properties.name`
  (no layout can ever emit `undefined` again); `frontage_arc` added to the
  center-camp-relative clock list → `"1:30 & Rod's Road"` (12:00 toward the Man).
- Regenerated `data/2026/geo/streets.geojson` (only the arc's name changed) and
  `data/2026/geocoder/bundle.js` (browserify 17.0.1, verified via a fresh VM
  context through the exact `window.prepare()`/`reverseGeocode()` interface both
  apps use).
- Docs year-bump: iBurn-Data + planner `README.md`/`CLAUDE.md` examples
  2025 → 2026 (the browserify example previously clobbered the 2025 bundle).

## New tests (`BlackRockCityPlanner/tests/Geocoder2026Test.js` + `layout2026.json`)

39 assertions, all passing; full suite 16/16 green (coverage gates intact):
- 12 org-derived intersection literals (one per ring; Esplanade/Kundalini nudged
  20' off the epsilon band, commented as such).
- Landmarks: Man → `0' Inner Playa`, Center Camp center → `Café`, 6:00 keyhole
  promenade → Inner Playa, far away → `Outside Black Rock City`.
- Rod's Road east/north arc points → `1:30 / 10:30 & Rod's Road`.
- **No-undefined sweep**: 0.002° grid over the whole city + margin.
- Forward: all 12 themed streets at 6:30 land at their layout ring distance
  (±10'); new 2:00/10:00 B Plazas resolve near the B ring; 4 forward↔reverse
  round trips.

## Phase 2 feasibility: org GeoJSON as source of truth

**What org data provides**: named street centerlines with widths
(`street_lines.geojson`: rings as letters A–K/ESP, radials as clock strings,
`Rods Road`, `Route 66`), 12 named plazas, 59 named CPNs (incl. The Man, Temple,
portals, plazas, Artery, Playa Info), trash fence, city blocks, DMZ, toilets,
gate road. Radii/geometry are authoritative — our layout was already derived
from them.

**What it lacks** (still needs a small per-year config): themed street names
(letter → name map, 12 entries — announced by BMorg, never in the GIS drop),
city bearing / clock convention (derivable but simpler declared), event dates.
That config is ~20 lines of JSON vs today's ~200-line handcrafted layout, and
**generate-time street synthesis disappears entirely**.

**Reverse algorithm on org data** (mirrors the legacy cascade, ~200-300 lines
of geometry): point → polar (time, distance) from The Man; containment checks
against plaza polygons/fence; otherwise nearest named centerline within
width/2 + ε → `time & name` (center-camp roads use Center Camp center for the
clock); open playa → `time & distance'` split into Inner/Outer at the
Esplanade/K radii sampled from the actual centerlines at that bearing. Needed
primitives: bearing, haversine distance, nearest-point-on-polyline,
point-in-polygon — no turf/JSTS required.

**Recommended architecture** (over keeping a JS bundle or Kotlin Multiplatform):
twin native ports — Swift in `PlayaGeo` (works on watchOS, kills the JSContext
startup cost that makes today's blocking call sites risky, removes both
year-hardcoded paths), Kotlin on Android — kept in lockstep by a shared
**conformance test-vector file** generated from org data per year (the 512
intersections + plazas + CPNs + playa/fence cases, JSON in
`iBurn-Data/data/<YEAR>/geocoder/`). The vector generator is this session's
validation sweep, productized.

**Scope split**: port **reverse only** natively (it runs constantly in UI).
Forward geocoding (fuzzy grammar, plaza-perimeter formats) stays in the JS data
pipeline where it runs rarely (import-time backfill), or gets ported later.

**Note on `~/Downloads/placement_geojson`** (`camp_labels/camp_outlines`): CAD
stroke LineStrings with only `fid`/`Layer` props — useful as future map layers
(the 2026 Map.bundle camp overlays are currently empty stubs), not needed for
reverse geocoding.

## Remaining work / follow-ups

- [ ] **Android**: copy rebuilt `data/2026/geocoder/bundle.js` →
      `iBurn-Android/iBurn/src/main/assets/js/bundle.js` (was still 2025).
- [ ] Mirror the three commits to the main `iBurn-iOS` checkout (user builds
      there; worktree-only changes get lost — see memory).
- [ ] Phase 2: test-vector generator CLI in BlackRockCityPlanner; Swift reverse
      port in `PlayaGeo` behind the existing `PlayaGeocoder` API; Kotlin port.
- [ ] Optional polish: pad the streets-area outer boundary by half a road width
      to absorb the K-centerline epsilon band.
- [ ] iOS app build/test not run this session — **disk was down to <1 GB free**
      (found 13.6 GB of stale Claude-session DerivedData under
      `/private/tmp/claude-501/…iBurn-iOS{,-2}/…`; bulk delete was blocked by
      the permission classifier — user to clean).

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
