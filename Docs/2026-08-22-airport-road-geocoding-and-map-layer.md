# 2026-08-22 — Airport Road: geocoding + map layer

## High-Level Plan

**Problem** (user report via Facebook): the iBurn map draws no **Airport Road**, and the
**Black Rock Travel Agency** (BRTA) theme camp at the airport is missing from the map.

**Diagnosis**

1. Two camps in `data/2026/APIData/APIData.bundle/camp.json` publish
   `location_string: "Airport Road"` (frontage `Airport Road`, no intersection) and have
   no GPS:

   | uid | name |
   |---|---|
   | `a1XVI00000FMQkn2AH` | Black Rock Travel Agency |
   | `a1XVI00000FKmxV2AT` | Flybynyte |

   Neither has a placement polygon in `data/2026/placement/` (they are in the
   "no polygon in either source" bucket the placement README describes), so the address
   geocode is their only source of a coordinate — and it failed. `src/cli/api.js`
   logged `could not geocode …` for both, so `camp.location.gps_*` was absent, so the
   app had no pin.

2. The forward geocoder (`src/orggeocoder/forward.js`) resolves a bare address with no
   clock token via `matchLandmark(input)`. Landmarks are keyed by normalized plaza/CPN
   names; the official CPN is `Airport`, and `"airport road"` neither matches it exactly
   nor within the Levenshtein fuzzy threshold of 0.25 (5/13 ≈ 0.38).
   `stripStreetDecorations()` already existed but was only applied on the ring-matching
   path.

3. BMorg's official 2026 GIS drop (`bmorg/innovate-GIS-data/2026/GeoJSON/`) has **no**
   Airport Road line, and the map tiles are built entirely from that drop, so nothing
   drew the road. (`data/2026/geo/streets.geojson` has a synthesized Airport Road from
   `streetplanner.js getAirportRoad`, but that file has not fed the tiles since the
   2026-07-13 move to official geometry.)

**Solution** — three layers, mirroring the 2026-07-25 Gate Road precedent:

1. Geocoder: a config-supplied `extra_landmarks` entry for `"Airport Road"`, plus a
   general street-decoration fallback on the bare-landmark path.
2. Data: re-geocode the two camps and re-run `apply_placement.js`.
3. Map: a hand-authored `airport_road` GeoJSON layer, tiled and styled in both themes.

## Technical Details

### A. Geocoder

`Submodules/iBurn-Data/scripts/BlackRockCityPlanner/src/orggeocoder/forward.js`

Two changes:

* **Decoration fallback on the bare-landmark path.** After `matchLandmark(input)` fails,
  and only when the address carries no clock token, retry with
  `stripStreetDecorations(input)`. Guarding on "no time token" keeps every real street
  address out of this path — those already went through `matchRing()`, which strips
  decorations itself.

  ```js
  var landmark = this.matchLandmark(input);
  if (!landmark && !parts.time) {
    var strippedInput = stripStreetDecorations(input);
    if (strippedInput && strippedInput !== input) {
      landmark = this.matchLandmark(strippedInput);
    }
  }
  ```

* **`extra_landmarks` from the year's config**, overlaid on the landmark table after the
  plazas and CPNs so a hand-surveyed point beats a generic one:

  ```js
  var extra = (dict.config && dict.config.extra_landmarks) || {};
  Object.keys(extra).forEach(function(name) {
    var coordinates = extra[name].coordinates || extra[name];
    this.landmarks[normalize(name)] = turf.point(coordinates);
  }, this);
  ```

`data/2026/geocoder/config.json` gains:

```json
"extra_landmarks": {
  "Airport Road": {
    "coordinates": [-119.212645, 40.761461],
    "note": "Not a CPN and not in the GIS drop: the airport-village camps address themselves to 'Airport Road'. This is a point on data/2026/geo/airport_road.geojson, 75 m up the road from its trash-fence end toward the city, where the camps sit (the 'Airport' CPN itself is ~210 m east, past the fence corner)."
  }
}
```

Why not the `Airport` CPN itself: BRTA describes itself as "the west half of the
airport", and on the 2026 BRC Public Map the airport village sits where Airport Road
meets the fence corner — west/northwest of the airport icon. The chosen point is on the
road, 75 m city-side of its fence-corner end.

Resulting behaviour (before → after):

| address | before | after |
|---|---|---|
| `Airport` | `-119.2101021, 40.7605453` (CPN) | unchanged |
| `Airport Road` | *undefined* | `-119.212645, 40.761461` |
| `Airport Rd` / `airport road` / `AIRPORT ROAD` | *undefined* | same point (fuzzy `airport rd` → `airport road` = 0.167) |
| `Rod's Road` / `Rods Road` / `Route 66` | *undefined* (retired for 2026) | unchanged |
| 2025 forward sweep, 1369 published camp addresses | all resolve, median 7' | unchanged |

Tests: `tests/OrgGeocoderTest.js` gains `orgForwardDecoratedLandmarks2026`, which asserts
all four spellings agree, the point is 1–250 m from the CPN, is closer to the Man than
the CPN, lies within 5 m of the `airport_road.geojson` line, that the three retired
street names still fail, and that `6:30 & Esplanade` and `6:30 & Esplanade St` agree.

```
npm test   # before: 17/17 files pass (1 skip), exit 0
           # after:  17/17 files pass (1 skip), exit 0, coverage gates met
```

Bundle rebuild (two steps, per `Docs/2026-07-25-geocoder-handoff.md`):

```bash
cd Submodules/iBurn-Data/scripts/BlackRockCityPlanner
node src/cli/build_geocoder_data.js --data-root ../../ --year 2026 \
  --output ../../data/2026/geocoder/geocoder-data.json
browserify src/orggeocoder/index.js -o ../../data/2026/geocoder/bundle.js
```

`bundle.js` 868190 → 869642 bytes. Verified through the built bundle (the same entry
points iOS JavaScriptCore uses):

```
Airport Road -> -119.212645,40.761461
Airport Rd   -> -119.212645,40.761461
Airport      -> -119.2101021,40.7605453
6:15 & A == A & 6:15 -> -119.21630310314207,40.778355214565224   (PlayaGeocoderTests assertions)
Center Camp Plaza @ 7:30 -> -119.21648201901638,40.777427585056124
reverse(40.7901,-119.2199) -> "8:44 & Eternal"
```

`geocoder-data.json` also picked up an unrelated, already-committed upstream change: the
`Point 3` CPN moved `(-119.1866721, 40.7992884)` → `(-119.1867226, 40.7993267)`. The
checked-in data file predated the last `bmorg` submodule bump; nothing else differs.

Reverse geocoding is unchanged — a point at the airport is outside the fence and still
reverses to "Outside Black Rock City", which is correct.

### B. Camp re-geocode

```bash
# the two Airport Road records only, so api.js's whole-file reformat (4-space indent,
# null-key stripping) never touches the other 1182 camps
node src/cli/api.js -l ../../data/2026/layouts/layout.json \
  -f "$TMPDIR/airport_camps.json" -k location_string -o "$TMPDIR/airport_camps_geocoded.json"
# merge the two gps pairs back into camp.json (rounded to 6 dp, matching apply_placement)
node scripts/apply_placement.js --year 2026        # mandatory follow-up; idempotent
```

`camp.json` diff — exactly two records, 6 insertions / 2 deletions:

```diff
@@ Flybynyte @@
-      "exact_location": null
+      "exact_location": null,
+      "gps_latitude": 40.761461,
+      "gps_longitude": -119.212645
@@ Black Rock Travel Agency @@
-      "exact_location": null
+      "exact_location": null,
+      "gps_latitude": 40.761461,
+      "gps_longitude": -119.212645
```

`apply_placement.js` reports `camp.json: unchanged (no timestamp bump)` — it is a no-op
over the edit, and the counts move exactly as expected:

```
GPS from polygon centroid:  1175
GPS from address geocode:   4      (was 2)
GPS from entrance centroid: 0
Camps still without GPS:    5      (was 7)
```

Because `apply_placement.js` only bumps `update.json` when it changes `camp.json` itself,
`camps.updated` was bumped by hand (same Pacific ISO-8601 format the script emits) so
existing installs re-import over their older database.

Both camps share one coordinate; the app fans overlapping pins, so that is fine.

### C. Airport Road map layer

New hand-authored file `Submodules/iBurn-Data/data/2026/geo/airport_road.geojson`: one
`LineString` with `name: "Airport Road"`, two vertices, traced against the 2026 BRC
Public Map:

* start `[-119.213261369, 40.767989688]` — the outermost vertex of the official `5:00`
  radial in `street_lines.geojson`, which is exactly on the `K` (Kundalini) ring
  centerline (0.0 m from it), i.e. the 5:00 & Kundalini intersection.
* end `[-119.212581530, 40.760788246]` — the trash-fence vertex nearest the airport
  (`trash_fence.geojson`, the `Point 5` CPN).

Sanity checks: the start is inside the fence, the end is on it, the segment length is
803 m on a bearing of 175.9°, and the airport is outside the fence to the southeast —
so the road exits the city at ~5:00 and reaches the fence corner, as the public map
shows. No intermediate vertex needed.

Tile regeneration, from `Submodules/iBurn-Data/data/2026/` (the 2026-07-25 command plus
one `-L`; `-t "$TMPDIR"` is still required under the sandbox):

```bash
python3 ../../scripts/rename_official_streets.py \
  layouts/layout.json \
  ../../bmorg/innovate-GIS-data/2026/GeoJSON/street_lines.geojson \
  "$TMPDIR/street_lines_named_2026.geojson"

tippecanoe -t "$TMPDIR" --output=Map/Map.bundle/map.mbtiles -f \
  -L fence:../../bmorg/innovate-GIS-data/2026/GeoJSON/trash_fence.geojson \
  -L outline:../../bmorg/innovate-GIS-data/2026/GeoJSON/street_outlines.geojson \
  -L points:../../bmorg/innovate-GIS-data/2026/GeoJSON/cpns.geojson \
  -L blocks:../../bmorg/innovate-GIS-data/2026/GeoJSON/city_blocks.geojson \
  -L plazas:../../bmorg/innovate-GIS-data/2026/GeoJSON/plazas.geojson \
  -L streets:"$TMPDIR/street_lines_named_2026.geojson" \
  -L toilets:../../bmorg/innovate-GIS-data/2026/GeoJSON/toilets.geojson \
  -L dmz:../../bmorg/innovate-GIS-data/2026/GeoJSON/dmz.geojson \
  -L gate_road:../../bmorg/innovate-GIS-data/2026/GeoJSON/gate_road.geojson \
  -L airport_road:geo/airport_road.geojson \
  -z 14 -Z 4 -B0
```

Result — 10 layers / 956 features / 294912 bytes (was 9 / 952 / 290816); bounds, tile
count and zoom range unchanged (`-119.273565,40.745943,-119.181240,40.803521`, 35 tiles,
z4–14), because the new line is well inside the Gate Road extent.

```
$ sqlite3 map.mbtiles 'select value from metadata where name="json"'   # vector_layers
airport_road [name, note, source]
blocks [FID, OBJECTID]
dmz [OBJECTID, Shape_Area, Shape_Length]
fence [FID, OBJECTID, Shape_Area, Shape_Length]
gate_road [FID]
outline [FID, OBJECTID]
plazas [FID, OBJECTID, name]
points [FID, NAME, OBJECTID, TYPE]
streets [OBJECTID, kind, name, source, width_ft]
toilets [OBJECTID, Shape_Area, Shape_Length, class]
```

Styles (`data/2026/Map/Map.bundle/styles/iburn-{light,dark}.json`) gain two layers each:

* `airport-road` — `line`, immediately after `gate-road`, identical paint
  (`line-color` `#C3B8AB` light / `#574e26` dark, same width stops), so the road reads as
  the same material as the city streets.
* `airport-road-label` — `symbol` on the same source-layer, immediately after `streets`,
  copying the street label paint/layout (`{name}`, `symbol-placement: line`, size 14).
  Unlike Gate Road, this line carries a `name`, so it can be labelled.

Layer order is now `… fence → outline → gate-road → airport-road → camp-boundaries →
camp-labels-big → streets → airport-road-label → toilet-icon → points → man`.

The tippecanoe command and a note on the layer's hand-authored provenance were added to
`Submodules/iBurn-Data/CLAUDE.md` and `README.md`.

No app source changed. `Map.bundle` ships through the SwiftPM target `iBurn2026Map`
(`Submodules/iBurn-Data/Package.swift`, `.copy("Map.bundle")`); the stale-tile-cache fix
in `iBurn/Bundle+iBurn.swift` (2026-07-13) already refreshes the Application Support copy
when the bundled mbtiles differs, so no version bump or manifest change is needed.
`PlayaGeocoder.xcodeproj` references `bundle.js` straight out of the submodule
(`path = "../../Submodules/iBurn-Data/data/2026/geocoder/bundle.js"`) and is a subproject
dependency of the app target, so the framework rebuilds automatically — there is no
vendored artifact to refresh.

### D. Verification

```bash
swift run --package-path Packages/PlayaSeed playa-seed --fetch-media
# art 331 · camps 1184 · events 5778 · mutant vehicles 493 · thumbnail colours 1574
```

```
sqlite> select uid,name,gps_latitude,gps_longitude,location_string from camp_objects
        where uid in ('a1XVI00000FMQkn2AH','a1XVI00000FKmxV2AT');
a1XVI00000FKmxV2AT  Flybynyte                 40.761461  -119.212645  Airport Road
a1XVI00000FMQkn2AH  Black Rock Travel Agency  40.761461  -119.212645  Airport Road
sqlite> select count(*) from camp_objects where gps_latitude is null;   -- 5 (was 7)
```

| check | result |
|---|---|
| `npm test` (BlackRockCityPlanner), before | 17/17 files, exit 0 |
| `npm test`, after | 17/17 files, exit 0, coverage gates met |
| `xcodebuild -scheme iBurn` (iPhone 17 Pro Max, iOS 26.5) | 0 errors, 0 warnings |
| `swift test --package-path Packages/PlayaDB --filter ReimportUpgradeTests` | 7 passed |
| `xcodebuild test -scheme iBurnTests` | 0 failures (16 pre-existing Pods `has no symbols` libtool warnings) |
| `PlayaGeocoder (iOS)` scheme test action | still not configured (pre-existing; the handoff doc flags it). Its three assertions were re-verified through the rebuilt bundle instead. |

## Context Preservation

* `src/cli/api.js` rewrites the whole file it is given: it deletes null-valued keys and
  writes 4-space JSON, while `camp.json` ships 2-space with nulls intact. Running it over
  the full `camp.json` would have produced a ~1184-record diff and dropped `null`
  placement fields, so it was run over a 2-record extract instead and the two `gps_*`
  pairs merged back. Same command, same geocoder, minimal diff.
* `apply_placement.js --gps-source auto` does **not** call the geocoder; its "address
  geocode" source is whatever GPS `camp.json` already holds. So the api.js step has to
  come first, and re-running `apply_placement.js` afterwards is what proves the other
  1182 camps' centroids are untouched.
* The simulator drive-through was skipped: the tile/style change was verified with
  `tippecanoe-decode` instead (14 tiles carry a named `Airport Road` feature in the
  `airport_road` layer), and the camp pins were verified in the built seed database.
* The geocode target is 237 m from the `Airport` CPN, not the ≤150 m originally assumed.
  The gap is real geography, not error: the CPN sits ~210 m east of the fence corner the
  road ends at. The test bound is 250 m, and the "city-side of the CPN" assertion pins
  the direction.

## Cross-References

* `Docs/2026-07-25-bmorg-geojson-refresh-gate-road.md` — the Gate Road layer this one
  mirrors (style paint, layer order, tippecanoe invocation).
* `Docs/2026-07-25-geocoder-handoff.md` — org-GeoJSON geocoder, two-step bundle build,
  and the still-open `PlayaGeocoder` test-action gap. Its "suggested next work" already
  noted that `poi.json` places the Airport by time+distance, 700' from the official CPN.
* `Docs/2026-07-13-official-2026-map-tiles.md` — the move to official geometry and the
  stale-tile-cache fix.
* `Submodules/iBurn-Data/data/2026/placement/README.md` — why these two camps have no
  polygon and therefore depend on the address geocode.

## Expected Outcomes

* Airport Road renders, labelled, in both light and dark themes, running from 5:00 &
  Kundalini out to the fence corner at the airport.
* Black Rock Travel Agency and Flybynyte have coordinates, so they appear on the map and
  in distance-sorted lists instead of being invisible.
* Any future address of the form `<landmark> Road/Rd/St/Ave` resolves to the landmark
  instead of failing.
