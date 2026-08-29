# 2026 Year Update Plan (2025 → 2026)

**Date:** 2026-07-03 (Pacific)
**Status:** IMPLEMENTED & VERIFIED (all workstreams complete, all tests green). Nothing committed or pushed yet.

**Final verification results (2026-07-03):**
- App builds clean (0 errors) and runs in simulator: 2026 map, data, and reverse geocoding all correct.
- PlayaAPI package: 54/54. PlayaDB package: 146 tests, 0 failures, 4 embargo skips.
- iBurnTests: full suite green after fixes (96 passed + ObjectListViewModelTests deterministic after mock-provider fix).
- `ObjectListViewModelTests.testToggleFavoriteCallsProvider` was a pre-existing broken test (April 2026 ListRow refactor): the mock provider never re-yielded rows with metadata after `toggleFavorite`, and the VM's optimistic update no-ops on nil metadata. Fixed the mock to mirror the real GRDB observation (re-yield with fresh `ObjectMetadata` on toggle) — unrelated to the year flip but fixed en route.
**Branch:** `2026-updates`

## Implementation Log (2026-07-03)

Workstream A (iBurn-Data, all local, uncommitted):
- A1 ✅ Removed `iBurn-2025.zip` + `.DS_Store`; `org-datasets/` now holds `2026 BRC Measurements.pdf`, `BRC_City_Plan_2026_update.pdf`, `Burning_Man_2026_Location_Data.md` (full transcription + computed radii table).
- A2 ✅ `layouts/layout.json`: new center `[-119.207871, 40.783242]`, `fence_distance` 8287, all 12 cStreets renamed/re-radiused (Ararat…Kundalini), added 2:00 + 10:00 B Plazas, 2:15/9:45 community paths now terminate at Iroko (double-wide I–K end blocks). `poi.json`/`toilet.json` carried over (address-relative, re-geocode automatically).
- A3 ✅ `APIData.bundle`: art/camp/event pretty-printed + mv minified from `/Users/chrisbal/Documents/Code/API/*-2026.json`; `update.json` timestamps refreshed; `dates_info.json` → Aug 30–Sep 7 2026, majorEvents 9 entries (burns on last three days). Verified: 321/1201/2140/499 records, all `year: 2026`. `majorEvents` is not parsed by app logic (only `BundleDataLoader.loadDatesInfo` + tests).
- A4 ✅ `generate_all.js` regenerated `geo/*.geojson`. **Validation: generated fence pentagon matches all 5 official surveyed fence points within ~10 m.** Street names + all 12 plazas + 5 portals present in polygons/streets output.
- A5 ✅ `geocoder/bundle.js` rebuilt. **Gotcha: `scripts/BlackRockCityPlanner/src/geocoder/index.js` hardcodes the year's layout path** — bumped `data/2025` → `data/2026` (uncommitted change in the BRCP submodule). Smoke tests pass: "9:00 & Ararat", "2:00 B Plaza", "3:00 & 500'" geocode; "4:30 & Kundalini" lands exactly due south of the Man (bearing check ✓).
- A6 ✅ tippecanoe → `Map.bundle/map.mbtiles` (139 KB, z4–14, 7 layers: dmz/fence/outline/points/polygons/streets/toilets). Bounds match 2026 fence. **Gotcha: tippecanoe needs `-t "$TMPDIR"` under the sandbox.** Style only references generated-layer names, so generated tiles are fully compatible. Official-GIS redo deferred (innovate-GIS-data has no 2026 yet).
- A7 ✅ Styles: `asset://iBurnData_iBurn2025Map.bundle` → `iBurn2026Map` (3 refs each in light/dark). `camp_labels.geojson`/`camp_outlines.geojson` replaced with empty FeatureCollections (2025 placement data removed, ~26 MB saved).
- A8 ✅ MediaFiles.bundle: cleared 2025 media (1355 files incl. 87 audio-tour m4a), downloaded **1574/1574 thumbnails, 0 failures** (art 316, camp 760, mv 498) keyed `<uid>.jpg` from widen.net CDN. Audio tour deferred.
- A9 ✅ Renamed `iBurn2025*` → `iBurn2026*`: wrapper sources in `data/2026/{APIData,Map,MediaFiles}/`, `Tests/iBurn2026*Tests/` dirs+files+identifiers+year literals, root `Package.swift` products/targets/paths → `data/2026`. (`swift build` inside the session sandbox fails on SwiftPM's nested sandbox-exec; validation via xcodebuild instead.)

Workstream B (app repo, uncommitted):
- `YearSettings.plist`: 2026 / Aug 30 07:00Z / Sep 7 07:00Z / Man 40.783242, -119.207871.
- `iBurn2025` → `iBurn2026` in `Bundle+iBurn.swift`, `project.pbxproj` (3 product deps), `PlayaAPI`+`PlayaDB` `Package.swift`, `BundleDataLoader.swift`, `BundleDataIntegrationTests.swift`, `PlayaDBRealDataTests.swift`.
- `MARKETING_VERSION` 2025.5 → 2026.0; `iBurn-2026.sqlite`/folder in `BRCDatabaseManager.m`; `kBRCEntered2026EmbargoPasscodeKey` (re-arms embargo); `BRCArtObject.m` default year 2026; `NSDate+iBurn.m` mock-date fallback → `2026-09-04T11:00:00-07:00`.
- Tests: `BundleDataIntegrationTests` year literals → 2026; `PlayaDBRealDataTests` Thursday → `2026-09-03`, GPS + spatial tests get `XCTSkipIf` embargo guards (no GPS in 2026 data until gates). Fixture-only tests (EventObjectOccurrence, MockAPIData, BRCDataSorter w/ frozen `initial_data` bundle, previews) left at 2025 — self-consistent.
- Verified: 2026 event-type codes AND labels identical to 2025 (8 types) — no `BRCEventObject.swift`/`EventTypeInfo.swift` changes. Embargo logic already covers camp+event+art and unlocks via `eventStart`. `BRCSecrets.m` has no year refs; 2026 passcode hash still pending from BMorg.
- **Gotcha found at runtime: `PlayaGeocoder/PlayaGeocoder.xcodeproj/project.pbxproj` embeds `../../Submodules/iBurn-Data/data/YYYY/geocoder/bundle.js` by year-hardcoded path** — the app's reverse geocoder showed "3:31 & Farmer" (2025 street) until this was bumped to `data/2026`. Add to the annual checklist alongside `scripts/BlackRockCityPlanner/src/geocoder/index.js`.
- Data fix: 4 records (3 camps, 1 MV) had user-entered `url` values with spaces/commas ("http://a, b", page titles) that crash strict `URL` decoding in PlayaAPI — sanitized in the 2026 bundle (first URL token kept, else null). Consider adding sanitization to `fetch_and_geocode.js` for the August re-fetches.
- Runtime verification (simulator, iPhone 17 Pro Max): app launches, imports 2026 data, map renders the 2026 city (Ararat…Kundalini labels, toilets, POIs), nearby cards show 2026 camps, reverse geocode returns 2026 addresses ("2:40 & Eternal").
- **Test-fixture consequence of the year flip: `BRCRecurringEventObject.eventObjects()` (iBurn/BRCRecurringEventObject.m:38-90) drops occurrences outside `YearSettings.eventStart/eventEnd`.** Any fixture with prior-year dates silently imports zero events. Fixed by day-mapping the fixture dates into the 2026 window (Aug 24→Aug 30 … Aug 31→Sep 6): `iBurnTests/Fixtures/initial_data.bundle/event.json`, `updated_data.bundle/event.json`, the three `now` strings in `BRCDataSorterTests.swift`, and `MockServices.eventObject`'s occurrence (was crashing DetailViewModelTests via the dateless `BRCEventObject()` fallback). Add fixture re-dating to the annual checklist.

## High-Level Plan

Annual rollover of the app from Burning Man 2025 to 2026. Three workstreams:

1. **iBurn-Data submodule** — populate `data/2026/` (currently a byte-for-byte copy of `data/2025/`): new city layout geometry, fresh API data from `/Users/chrisbal/Documents/Code/API`, regenerated geo/tiles/geocoder, renamed SwiftPM targets (`iBurn2026*`).
2. **App repo** — flip year-stamped code: `YearSettings.plist`, package product names, database name, embargo defaults key, marketing version, tests.
3. **Verification** — build, run, and test against the new data.

### Hard constraints (from Chris)

- **NO git pushes to any remote.** Local commits only, and only when authorized. The iBurn-Data submodule `origin` is the *private* repo (`iBurnApp/iBurn-Data-Private`) with a `public` remote; `.gitmodules` in the app repo currently points at the public URL with the private one commented out. 2026 API data must stay private if it ever contains location data.
- Current 2026 API data is **fully embargoed**: every `location`/`location_string` in art and camp is `null`. No GPS anywhere. So nothing sensitive exists yet, but the no-push rule stands.

---

## Key 2026 Facts (verified against official sources)

Sources: `2026 BRC Measurements.pdf` (bm-innovate S3, dated 2.25.2026), `BRC_City_Plan_2026_update.pdf` (webassets), burningman.org 2026 city plan page, and the raw API pull at `/Users/chrisbal/Documents/Code/API/*-2026.json`.

### Event dates
- **Sun Aug 30 – Mon Sep 7, 2026** (Labor Day = Sep 7). API occurrences span `2026-08-30T17:00:00-07:00` → `2026-09-06T23:00:00-07:00`.
- Major events (same convention as 2025's last-three-days pattern): Man Burn **Sat Sep 5**, Temple Burn **Sun Sep 6**, Exodus **Mon Sep 7**.

### Geometry (Measurements PDF)
- **The Man (golden spike): `40.783242, -119.207871`** — moved significantly from 2025 (`40.786958, -119.202994`).
- Fence pentagon points: `40.779710,-119.237421` / P2 `40.803523,-119.221409` / P3 `40.799290,-119.186670` / P4 `40.772883,-119.181237` / P5 `40.760786,-119.212582`. Man→fence points **8287'** (2025: 8337 in layout.json).
- Center of Greeter's Gap: `40.770268, -119.225025`. Man→Haul Rd center 6435'. Man→fence @ Greeters 6705'.
- True N/S along 4:30 axis → **bearing 45 unchanged**.
- Esplanade 2500' from Man; Esplanade→A block 400' deep; A–E blocks 250'; **mid-city double blocks E–F 450'** ; I–K blocks 150'. K road diameter 11,510' → radius 5755'.
- Widths: radial avenues 40'; annular streets 30' except **E & Esplanade 40'**, **K 50'**. Community Paths (20', ped/bike) between F and K at 3:45, 4:15, 4:45, 5:15, 6:45, 7:15, 7:45, 8:15.
- Man → center of The Canopy (center camp) = 2999' (unchanged). Center Camp portal mouth at Esplanade: 210'.
- Plazas: portal plazas ring at **B = 3215'** (3:00, 4:30, 7:30, 9:00), mid-city ring at **G = 4825'** (3:00, 4:30, 6:00, 7:30, 9:00). Five portals to Esplanade: 3:00, 4:30, 6:00, 7:30, 9:00 (unchanged).
- **NEW per city-plan page: B Plazas at 2:00 and 10:00** ("along traditional sound avenues"). Also **double-wide blocks 2:00–2:30 and 9:30–10:00 between I–K** for large camps/HUBS. *Verify both against the city plan map PDF / GIS data when editing layout.json.*
- BRC Depot & Sanitation 670' from Kilgore→K center-to-center — identical wording to 2025, so the 2025 `dmz` block in layout.json can carry over.
- Walk-in camping: beyond K to fence, 2:00–5:00 (city plan map shows two walk-in areas).

### 2026 street names (from city plan PDF map — authoritative)
Esplanade, then A–K: **Ararat, Bodhi, Chomolungma, Delphi, Eternal, Fulcrum, Great Oak, Heiau, Iroko, Jiba, Kundalini**.
(Note: burningman.org page summary suggested "Ceiba" for C; the official map PDF clearly shows **Chomolungma**. The measurements PDF still says "Bradbury/Gibson/Kilgore" — stale 2025 names used as ring references only.)

### Computed 2026 cStreet radii (center-to-center; cross-checks: B=3215 ✓, G=4825 ✓, K=5755=11510/2 ✓)

| ref | name | distance (ft) | width | 2025 was |
|---|---|---|---|---|
| esplanade | Esplanade | 2500 | 40 | 2500 |
| a | Ararat | 2935 | 30 | 2940 |
| b | Bodhi | 3215 | 30 | 3220 |
| c | Chomolungma | 3495 | 30 | 3500 |
| d | Delphi | 3775 | 30 | 3780 |
| e | Eternal | 4060 | 40 | 4060 |
| f | Fulcrum | 4545 | 30 | 4540 |
| g | Great Oak | 4825 | 30 | 4825 |
| h | Heiau | 5105 | 30 | 5100 |
| i | Iroko | 5385 | 30 | 5380 |
| j | Jiba | 5565 | 30 | 5560 |
| k | Kundalini | 5755 | 50 | 5755 |

Derivation: gap = ½(inner width) + block depth + ½(outer width). E.g. A = 2500 + 20 + 400 + 15 = 2935; F = 4060 + 20 + 450 + 15 = 4545; K = 5565 + 15 + 150 + 25 = 5755. Note 2025's layout.json was ~5' off the official plaza ring (official 2025 md also said B=3215); the 2026 numbers above match the official anchors exactly.

### API data (already fetched, at `/Users/chrisbal/Documents/Code/API/`)
- `art-2026.json` (321 records, −11 vs 2025), `camp-2026.json` (1201, −184), `event-2026.json` (2140 events / 4526 occurrences), `mv-2026.json` (499, +276). All minified, valid UTF-8, no BOM.
- Schema identical to 2025 except two NEW booleans: art `needs_volunteers`, camp `accepting_campers` (harmless to Codable; optionally surface later).
- Event type codes **identical to 2025** (adlt, arts, food, kid, othr, prty, tea, work) — no changes needed in `BRCEventObject.swift` / `EventTypeInfo.swift`.
- All locations null (embargo). `uid`/`year` fields correct.

---

## Workstream A — iBurn-Data submodule (`Submodules/iBurn-Data`)

`data/2026/` is currently an exact copy of `data/2025/` (verified with `diff -rq`). Steps:

### A1. Clean the template
- Delete stray `data/2026/iBurn-2025.zip` (19.9 MB build artifact) and `.DS_Store` files.
- Replace `data/2026/org-datasets/` contents with 2026 source docs: save the two PDFs (measurements + city plan) and a `2026-city-plan.txt` / location-data markdown analogous to 2025's.

### A2. Hand-edit `data/2026/layouts/layout.json`
- `center.geometry.coordinates` → `[-119.207871, 40.783242]` (lon, lat).
- `fence_distance` → `8287`.
- `cStreets`: names + distances per table above (keep `segments` structure; Esplanade keeps its split segments around center camp; widths: only esplanade=40, e=40, k=50 explicit, matching 2025 style).
- `plazas`: keep 2025 set (B ring ×4, G ring ×5 incl. 6:00, Man Plaza), **add `2:00 B Plaza` and `10:00 B Plaza`** (diameter 200, distance "b") — verify against city plan map first.
- `tStreets`: verify the :15/:45 F→K streets against the 2026 map — the new double-wide I–K blocks at 2:00–2:30 and 9:30–10:00 may terminate 2:15 and 9:45 at I instead of K.
- `dmz`, `center_camp`, `entrance_road`, `portals`: carry over (measurements match 2025 wording); sanity-check entrance road/Greeters against new gap coordinates.
- `layouts/toilet.json`, `layouts/poi.json`: carry over initially (addresses are time/distance-based and geocode against the new layout); update POIs if 2026 info differs (Temple location, airport, medical usually stable early-season). Toilets get corrected when official GIS lands.

### A3. Populate `data/2026/APIData/APIData.bundle/`
- Copy `/Users/chrisbal/Documents/Code/API/{art,camp,event,mv}-2026.json` → `art.json`, `camp.json`, `event.json`, `mv.json`. Pretty-print art/camp/event with `jq` to match 2025 bundle formatting (mv.json stayed minified in 2025).
- `update.json`: refresh `updated` timestamps for all four entries (file mtime-style ISO timestamps like 2025's).
- `dates_info.json`: `rangeInfo` → start `2026-08-30T00:00:00-07:00`, end `2026-09-07T12:00:00-07:00`; `majorEvents` → same last-three-days convention (…, "Man Burn", "Temple Burn", "Exodus"). **Check the consumer of `majorEvents` (search code) to get array length/indexing right for a 9-day span.**
- `points.json` (empty FeatureCollection) and `credits.json` carry over.
- Locations stay null (embargo). Optional dev aid: `scripts/BlackRockCityPlanner/src/cli/mock_locations.js` can fabricate mock locations from a prior year for local testing — must never be committed/shipped.

### A4. Regenerate geometry
```bash
cd Submodules/iBurn-Data/scripts/BlackRockCityPlanner
npm install
node src/cli/generate_all.js -d ../../data/2026
```
Outputs `data/2026/geo/{streets,polygons,outline,fence,dmz,toilets,points}.geojson`. Spot-check in a geojson viewer: street names, new Man position, plaza set.

### A5. Rebuild geocoder
`browserify src/geocoder/index.js -o ../../data/2026/geocoder/bundle.js` (layout changed, so the embedded geometry must be rebuilt). Check `hardcoded_locations.js` for 2025-specific entries.

### A6. Regenerate map tiles
`bmorg/innovate-GIS-data` has **no 2026 folder yet**, so use the generated-geo tippecanoe variant from the repo CLAUDE.md (layers: fence, outline, polygons, streets, toilets, points, dmz; `-Z 4 -z 14 -B0`) → `data/2026/Map/Map.bundle/map.mbtiles`. The `points` layer with uppercase `NAME` is required for POI sprites. Redo from official GIS when BMorg publishes 2026 (tracked in Deferred).

### A7. Map bundle styles + camp layers
- `Map.bundle/styles/iburn-{light,dark}.json`: update `asset://iBurnData_iBurn2025Map.bundle/...` → `iBurnData_iBurn2026Map.bundle` (glyphs + camp geojson sources).
- Replace `camp_labels.geojson` (25.7 MB) and `camp_outlines.geojson` with **empty FeatureCollections** — they contain 2025 placement data; 2026 placement won't exist until ~gates. Keeps the style layers valid and drops ~26 MB. (`/Users/chrisbal/Downloads/placement_geojson` is the *2025* placement source, dated Aug 2025 — not usable for 2026.)

### A8. MediaFiles bundle
`data/2026/MediaFiles/MediaFiles.bundle` currently holds 1358 2025 files (art/camp jpg + audio-tour m4a). For the initial 2026 build: clear 2025 media, download 2026 thumbnails from `images[].thumbnail_url` (art 316/321 have images, camp 760/1201, mv 498/499) using the same file-naming convention (verify how `Bundle.brc_mediaFileURL`/`brc_loadMediaData(fileId:)` keys files — likely by uid). Audio tour arrives later in the season. If we want a smaller first pass: ship empty media bundle and add media in a follow-up like 2025 did (commits `efbed09`, `6618625`, `7f5a3be`).

### A9. Rename SwiftPM targets to 2026
- Rename `data/2026/APIData/iBurn2025APIData.swift` → `iBurn2026APIData.swift` (update `year` and bundle-name strings inside); same for `Map/iBurn2025Map.swift`, `MediaFiles/iBurn2025MediaFiles.swift`.
- Root `Package.swift`: products/targets `iBurn2025*` → `iBurn2026*`, `path:` → `data/2026/...`.

### A10. Local commit (submodule) — **no push**

---

## Workstream B — App repo

Modeled on last year's commits (`947c4f5` "Working on 2024" — the canonical rollover; `fe76662` "2025 data" — final submodule bump; `a552efd` — embargo key; `61a3b46` — repo flip):

1. **`iBurn/YearSettings.plist`** — `PlayaYear` `2026`; `EventStart` `2026-08-30T07:00:00Z`; `EventEnd` `2026-09-07T07:00:00Z` (midnight PDT convention, matching 2025's values); `ManCenterLatitude` `40.783242`, `ManCenterLongitude` `-119.207871`. Embargo unlock date derives from `EventStart` automatically (`BRCEventObject.m:153` → `BRCEmbargo.m:47`).
2. **`iBurn/Bundle+iBurn.swift`** — `import iBurn2025APIData/Map/MediaFiles` → `iBurn2026*` (≈12 references).
3. **`iBurn.xcodeproj/project.pbxproj`** — three `XCSwiftPackageProductDependency` names → `iBurn2026*`; `MARKETING_VERSION` `2025.5` → `2026.0`. (Watch for the known DEVELOPMENT_TEAM pbxproj dirtying — revert any team flip before committing.)
4. **`Packages/PlayaAPI/Package.swift` & `Packages/PlayaDB/Package.swift`** — test dependency product → `iBurn2026APIData`.
5. **`iBurn/BRCDatabaseManager.m:30-31`** — `iBurn-2026.sqlite` / `iBurn-2026` folder (forces clean rebuild).
6. **`iBurn/NSUserDefaults+iBurn.m`** — `kBRCEntered2025EmbargoPasscodeKey` → `...2026...` (re-arms embargo).
7. **`iBurn/BRCArtObject.m:122`** — default year `2026`.
8. **`iBurn/BRCSecrets.m`** (untracked, local) — new `kBRCEmbargoPasscodeSHA256Hash` when BMorg issues the 2026 passcode (deferred; keep old hash until then). Verify `kBRCUpdatesURLString` will serve the 2026 `update.json` (no year string embedded in the file today).
9. **Embargo policy check** — 2025 removed camp/event embargo keeping art-only (`21b5794`). Confirm desired 2026 behavior; moot until location data exists, revisit in August.
10. **Tests/fixtures** — update `iBurn2025APIData` imports and 2025-hardcoded dates/years in: `Packages/PlayaAPI/Tests/**` (esp. `BundleDataIntegrationTests`), `Packages/PlayaDB/Tests/**` (esp. `PlayaDBRealDataTests` — record-count assertions must change to 2026 counts: 321/1201/2140/499), `iBurnTests/**` (`BRCDataSorterTests`, `RightNowCandidateTests`, `NearbyCardViewModelTests`, etc.), `MockServices.swift`, SwiftUI previews.
11. **`Package.resolved` + submodule pointer** — after the submodule commit.

---

## Workstream C — Verification

1. `xcodebuild build` (iPhone 17 Pro Max, OS 26.2 sim) via xcsift — clean compile with renamed packages.
2. Run app in sim: fresh DB import (expect 321 art / 1201 camps / 2140 events / 499 MVs), map centered on new Man location with 2026 streets (Ararat→Kundalini), POIs render, no camp outline layer errors, event list spans Aug 30–Sep 7, gate countdown correct, embargo screen active.
3. Test suites: `iBurnTests`, `PlayaKitTests`, PlayaAPI + PlayaDB package tests — all green after fixture updates.
4. Geometry spot-check: geocode a few addresses via BRCP tests (`npm test`), e.g. "9:00 & Ararat", "Center Camp Plaza".

---

## Deferred (August 2026, as data lands)

- Re-fetch API with `fetch_and_geocode.js -y 2026` once location data unlocks (needs `BMORG_API_KEY`); geocode camps; re-verify event types.
- Official 2026 GIS tiles when `burningmantech/innovate-GIS-data` publishes 2026 (redo tippecanoe per `Docs/2025-07-19-map-tiles-official-data.md`).
- 2026 placement geojson → regenerate `camp_labels.geojson` / `camp_outlines.geojson`.
- 2026 media files + audio tour; 2026 embargo passcode hash; `.gitmodules` private/public flip decisions; `credits.json` refresh.

## Open questions / decisions taken

- **Rename data targets to `iBurn2026*`** (matches every prior year's pattern) rather than keeping 2025 names — requires the coordinated app-side renames in B2–B4.
- **Empty camp label/outline layers** for launch (placement data doesn't exist yet).
- **2:00/10:00 B Plazas + double-wide I–K end blocks**: city-plan page says yes; measurements PDF is silent — verify against the map PDF while editing layout.json.
- **Media**: download 2026 thumbnails during A8 vs. ship-empty-first — either works; plan assumes download now, fallback to empty.

## Context: how last year's update actually went (git archaeology)

- **iBurn-Data**: `728172c` "2025 template" (copy prior year, Jun 28) → `7ab12a5` "2025" (layout.json edit + full geometry regen + tiles, Jun 28) → July: bundle restructure (`d01b186`), swiftpm (`e38bd7d`), tiles (`dfd4030`), geocoder bundle.js (`fdf039c`), org data (`d9bb5be`), location mocker (`601e629`) → August: repeated "Pull fresh API data" + geocoder fixes + media/audio commits → `6a79c73` placement geojson + camp layers (Aug 23–24) → `9dbe557` final data (Aug 24).
- **App repo**: year-flip file set per `947c4f5`; season of point releases `2025.1`→`2025.5`; `21b5794` embargo relaxation; `fe76662`/`d9d816a` data bumps; `61a3b46` "Use public repo again" post-event.
- Takeaway: the rollover is a June/July structural pass (exactly this plan), then an August cadence of data refreshes.
