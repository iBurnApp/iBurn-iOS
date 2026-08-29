# 2026-08-27 — API refresh + full camp geocode audit

## High-Level Plan

**Problem.** Gates open **2026-08-30**. The shipping data was last refreshed Aug 22, and
placement churns daily in the final week. Beyond a routine refresh we wanted positive
proof that *every* camp pin in the shipped seed is real — not just that the pipeline ran,
but that each coordinate agrees with the map layer it is drawn on, sits inside the trash
fence, and is near the address the camp published.

**Solution.**

1. Re-run the documented refresh (`fetch_and_geocode.js` → the mandatory
   `apply_placement.js` → `playa-seed`).
2. Add `Submodules/iBurn-Data/scripts/audit_camp_geocodes.js`, a standing audit that
   buckets every camp and asserts the invariant its bucket implies.
3. Fix the one parser gap the refresh surfaced (`"<time> & <time> <letter> Plaza"`).

**Outcome.** Audit is clean: 1175 camps placed from their footprint centroid (all
matching `camp_labels.geojson` exactly), 4 from the address geocode (all within 50 m of a
re-geocode), 0 geocode failures, 5 camps with no GPS *and* no address (nothing to
geocode — no coordinates invented), 0 null-island, 0 outside the fence.

## Technical Details

### Commands

```bash
cd Submodules/iBurn-Data/scripts/BlackRockCityPlanner
node src/cli/fetch_and_geocode.js -y 2026 -l ../../data/2026/layouts/layout.json \
  -o ../../data/2026/APIData/APIData.bundle          # BMORG_API_KEY from the environment

cd ../..                                             # Submodules/iBurn-Data
node scripts/apply_placement.js --year 2026          # MANDATORY follow-up
node scripts/audit_camp_geocodes.js --year 2026      # new

cd ../..                                             # repo root
swift run --package-path Packages/PlayaSeed playa-seed --fetch-media
```

### Count deltas (Aug 22 `eb0d48a` → Aug 27 `1c715ce`)

| | Aug 22 | Aug 27 |
|---|---|---|
| art | 331 | **332** |
| art at GPS 0,0 (known upstream test rows) | 20 | **16** |
| camps | 1184 | 1184 |
| camps with GPS | 1179 | 1179 |
| events (records) | 2876 | **3412** |
| event occurrences | 5778 | **6565** |
| mutant vehicles | 493 | **492** |
| `camp_outlines` / `camp_labels` features | 1175 | 1175 |
| thumbnail colour rows | 1574 | 1572 |
| seed zip size | 3155 KB | **3367 KB** |

The +536 events / +787 occurrences is the pre-gates flood of camp-published events —
expected this close to the event, not a pipeline artefact. Every feed has unique uids
(art 332/332, camps 1184/1184, events 3412/3412, mv 492/492). No `MOCK_LOCATIONS`
sentinel. No null-island camps.

`playa-seed` logged `Corrected 2 event occurrence times during import` — the existing
importer guard, not new.

### `bmorg/innovate-GIS-data`: no upstream changes

```
$ git -C Submodules/iBurn-Data/bmorg/innovate-GIS-data fetch --all
$ git rev-list --count HEAD..origin/HEAD
0                                    # HEAD = 4812b40 "moved P3 to pentagon (#11)"
```

Street, toilet, fence, CPN, plaza, block, DMZ, gate-road geometry is unchanged, so the
map tiles were **not** rebuilt and `geocoder-data.json` came out byte-identical. The
Aug 22 tippecanoe command (including `-L airport_road:geo/airport_road.geojson`) stands
unused this round.

### `apply_placement.js` — identical to Aug 22

```
Matched camps:              1183
Camps without placement:    1
Placement uids not in API:  8
Placement fields filled:    0
GPS from polygon centroid:  1175
GPS from address geocode:   4
GPS from entrance centroid: 0
Camps still without GPS:    5
Camps without any geometry: 9
Distinct GPS coordinates:   1178 (was 1178)
Outline features:           1175  (1175 direct export, 0 PDF-derived)
Label features:             1175  (1175 at polygon centroid)
camp.json:                  unchanged (no timestamp bump)   # idempotent re-run
```

Every number matches Aug 22's `1175 / 4 / 0 / 5`. 41 API-vs-drop field conflicts, all
resolved API-wins (Aug 22: 31) — the drop is now four days staler than the API, so more
textual disagreement is expected and the fill-only policy handles it.

### Airport Road camps — verified

`fetch_and_geocode.js` rewrites `camp.json` wholesale, so the Aug 22 hand-merged
coordinates were discarded and re-derived. They came back identical, which is the point
of putting the point in `data/2026/geocoder/config.json` rather than in the data:

```
a1XVI00000FKmxV2AT  Flybynyte                 40.761461  -119.212645  Airport Road
a1XVI00000FMQkn2AH  Black Rock Travel Agency  40.761461  -119.212645  Airport Road
```

Neither has a placement polygon, so this is the address geocode, and the audit confirms
both land inside the trash fence (75 m city-side of the fence corner).

## The geocode audit

### `Submodules/iBurn-Data/scripts/audit_camp_geocodes.js` (new)

Read-only. Run it after `apply_placement.js`. It requires `@turf/turf` and the org
geocoder factory out of `scripts/BlackRockCityPlanner/`, so no new dependency.

Every camp lands in exactly one bucket, and the bucket determines the check:

| Bucket | Meaning | Invariant checked |
|---|---|---|
| `polygon` | has a footprint in the placement drop | pin == its `camp_labels.geojson` point (≤1 m; both are written from the same 6-dp value) |
| `address` | no footprint, pin is the offline geocoder's answer | re-run `forward(location_string)`, flag > `--geocode-tolerance` (50 m) |
| `geocode-failure` | has a `location_string`, no GPS | **always a finding**, listed in full |
| `no-address` | no `location_string`, no GPS | unplaced upstream; expected |

Bucket-independent, on every placed camp:

* null island `(0,0)` or a non-finite coordinate,
* point-in-polygon against BMorg's official `trash_fence.geojson`,
* distance from its own address geocode, flagged past `--frontage-tolerance` (400 m) and
  summarised as a distribution.

Cross-layer consistency: a `camp_labels` feature whose uid has no camp, and a
`camp_outlines` feature with no matching label.

The fence test was sanity-checked against known points before trusting the zero:
Man → inside, Airport Road geocode → inside, `Airport` CPN → outside, far-southwest →
outside, `(0,0)` → outside. So "0 outside the fence" is a real result, not a predicate
that always answers true.

### Result

```
=== Buckets ===
Camps:                        1184
  placed from polygon:        1175
  placed from address geocode:4
  no GPS, has an address:     0  <- geocode failures
  no GPS, no address at all:  5  <- unplaced upstream

=== Checks ===
ok   Pin != its camp_labels point (placement not applied): 0
ok   Pin != re-geocode of its own address (>50 m): 0
ok   Null island / non-finite coordinate: 0
ok   Outside the trash fence: 0
ok   Far from its own address geocode (>400 m): 0
ok   camp_labels feature with no camp: 0
ok   camp_outlines feature with no label: 0

Pin-to-address-geocode offset over 1179 camps:
  median 51 m, p90 95 m, p99 144 m, max 372 m

PASS — no geocode failures or anomalies.
```

**Every camp lacking GPS, and why** — all five publish no `location_string` at all, so
there is nothing to parse. No coordinates were invented:

| uid | name |
|---|---|
| `a1XVI00000FG3Kf2AL` | Baby Boomer Burners |
| `a1XVI00000FHnOf2AL` | SP Station |
| `a1XVI00000FKoOD2A1` | Dusk |
| `a1XVI00000FMQsr2AH` | Huǒ Fèng MV Support Camp |
| `a1XVI00000FXjTx2AL` | Kalos Scopeo |

**The four address-geocoded camps** — the other half of `apply_placement`'s nine
"camps without any geometry" (9 = these 4 + the 5 unplaced above):

| uid | name | address | pin |
|---|---|---|---|
| `a1XVI00000FBhXF2A1` | Westlandia | `9:15 & F` | 40.793130, -119.217901 |
| `a1XVI00000FKmxV2AT` | Flybynyte | `Airport Road` | 40.761461, -119.212645 |
| `a1XVI00000FMQkn2AH` | Black Rock Travel Agency | `Airport Road` | 40.761461, -119.212645 |
| `a1XVI00000FTuSn2AL` | Yaass Daddy! | `B & 7:45` | 40.784394, -119.219395 |

The median 51 m pin-to-address offset is the expected signature of centroid pins: a camp
lot's centre is naturally tens of metres off the street-intersection point its address
names. The 372 m maximum is a large lot, not an error — nothing exceeded the 400 m
threshold.

## Parser fix — `"<time> & <time> <letter> Plaza"`

`fetch_and_geocode.js` reported exactly four address failures:

```
Could not geocode Orphan Asylum:    10:00 & 10:00 B Plaza
Could not geocode Nom De Plume:     10:00 & 10:00 B Plaza
Could not geocode Bo_b Squad:       2:00 & 2:00 B Plaza
Could not geocode Venice Red Light: 2:00 & 2:00 B Plaza
```

All four have placement polygons, so the shipped pins were never affected — but the same
geocoder is bundled into the app (`data/2026/geocoder/bundle.js` → `PlayaGeocoder`) for
user-typed addresses, so the gap is worth closing.

**Diagnosis.** The API writes the radial and then repeats it inside the plaza's own name.
`splitAddress()` keeps only the *first* clock token, leaving `feature = "B Plaza"`:

* the `^(.*plaza.*?)\s*[@&]\s*(\d{1,2}:\d{2})\s*$` perimeter form wants the time last — no match;
* `matchRing("B Plaza")` → `leven("b", "b plaza")/7 = 0.857`, past the 0.34 threshold;
* not a portal;
* `matchLandmark("10:00 & 10:00 B Plaza")` normalizes to `"10:00 10:00 b plaza"`, which is
  `6/19 = 0.316` from the `"10:00 b plaza"` key — **just past** the 0.25 fuzzy threshold;
* the decoration-strip retry is guarded on "no clock token", correctly skipped;
* `streetIntersectionToLatLon("10:00", "B Plaza")` → no ring → `undefined`.

**Fix** (`src/orggeocoder/forward.js`, inside the `parts.time && parts.feature` branch,
after the ring and portal attempts):

```js
if (/plaza/i.test(parts.feature)) {
  var plaza = this.matchLandmark(parts.time + ' ' + parts.feature);
  if (plaza) {
    return plaza.geometry.type === 'Point' ? plaza : turf.centroid(plaza);
  }
}
```

Re-attaching the time gives `"10:00 B Plaza"`, which is how plazas are keyed — an exact
hit, no fuzz. It also resolves the plain `"<time> & <letter> Plaza"` spelling.

**Blast radius.** Swept all **1085 distinct camp/art `location_string`s in the 2025 and
2026 API bundles** through `forward()` before and after. Exactly two entries changed —
the two failing forms. Everything else is byte-identical, including
`"10:00 B Plaza & B"` (which already fuzzy-matched) and every plaza-perimeter address.
The one remaining sweep failure is the 2025 art string `"Mobile"`, which is not an
address.

**Tests.** `tests/OrgGeocoderTest.js` gains `orgForwardRepeatedPlazaTime2026`: both
failing forms resolve to the same point as their bare plaza name; `"10:00 & B Plaza"`
does too; the plaza and the `10:00 & B` ring intersection stay distinct (>5 m apart);
plaza-perimeter, Center Camp perimeter and ordinary intersections still resolve; an
invented plaza name still fails.

```
npm test   # 17/17 files pass (1 skip), exit 0, coverage gates met
```

**Bundle rebuild** (two steps, per `Docs/2026-07-25-geocoder-handoff.md`):

```bash
node src/cli/build_geocoder_data.js --data-root ../../ --year 2026 \
  --output ../../data/2026/geocoder/geocoder-data.json     # unchanged (bmorg unchanged)
browserify src/orggeocoder/index.js -o ../../data/2026/geocoder/bundle.js
```

`bundle.js` 869642 → 870313 bytes. Verified through the built bundle — the same entry
points iOS JavaScriptCore uses:

```
10:00 & 10:00 B Plaza    -> -119.21139338,40.79165599
2:00 & 2:00 B Plaza      -> -119.19681891,40.78058766
Airport Road             -> -119.212645,40.761461
Airport                  -> -119.2101021,40.7605453
6:15 & A == A & 6:15     -> -119.21630310314207,40.778355214565224   (PlayaGeocoderTests)
Center Camp Plaza @ 7:30 -> -119.21648201901638,40.777427585056124
reverse(40.7901,-119.2199) -> "8:44 & Eternal"
```

All unchanged from the Aug 22 handoff values.

**`camp.json` was not re-geocoded for these four.** `apply_placement.js --gps-source auto`
prefers the polygon centroid, and all four have polygons, so writing an address geocode
into `camp.json` would be overwritten on the next run. The fix's value is the in-app
geocoder and future refreshes.

## Seed + verification

```
swift run --package-path Packages/PlayaSeed playa-seed --fetch-media
==> Downloading 1 missing thumbnail(s)… Downloaded 1, failed 0.
    Imported 332 art, 1184 camps, 6565 event occurrences, 492 mutant vehicles.
    thumbnail colours: 1572
    archives: 2 × 3367 KB   (iBurn/ and iBurnWatch/PlayaDB-2026.zip, byte-identical)
```

New thumbnail `data/2026/MediaFiles/MediaFiles.bundle/a2IVI000003H0wP2AS.jpg`, committed
in the submodule.

```sql
-- unzipped iBurn/PlayaDB-2026.zip
camps 1184 · camps with GPS 1179 · camps without GPS 5
art 332 · events 3412 · event_occurrences 6565 · mv 492 · thumbnail_colors 1572
camps at (0,0): 0

select uid,name,gps_latitude,gps_longitude,location_string from camp_objects
 where uid in ('a1XVI00000FMQkn2AH','a1XVI00000FKmxV2AT');
a1XVI00000FKmxV2AT|Flybynyte|40.761461|-119.212645|Airport Road
a1XVI00000FMQkn2AH|Black Rock Travel Agency|40.761461|-119.212645|Airport Road
```

| check | result |
|---|---|
| `npm test` (BlackRockCityPlanner) | 17/17 files, exit 0 |
| `xcodebuild -workspace iBurn.xcworkspace -scheme iBurn` (iPhone 17 Pro Max, iOS 26.5) | success, 0 errors, 0 warnings |
| `swift test --package-path Packages/PlayaDB --filter ReimportUpgradeTests` | 7 passed |
| `swift test --package-path Packages/PlayaDB --filter NameOrderingTests` | 8 passed |
| `git status` on `iBurn.xcodeproj/project.pbxproj` | clean — no `DEVELOPMENT_TEAM` flip to revert |

## Context Preservation

* `git fetch` inside the sandbox printed `failed to store: 100001` and reported a stale
  answer; re-running with the sandbox disabled gave the true result (0 behind). Always
  disable the sandbox for the bmorg fetch.
* `browserify` is only on `PATH` at `/opt/homebrew/bin/browserify`; it is *not* in
  `scripts/BlackRockCityPlanner/node_modules/.bin`.
* The audit script deliberately re-runs `forward()` twice per camp (once for the
  address-bucket check, once for the frontage distribution). At 1184 camps that costs
  nothing and keeps the two checks independent.

## Cross-References

* `Docs/2026-08-22-case-insensitive-name-sorting.md` — "API data refresh (Aug 22)", the
  previous refresh and the placement regression it fixed.
* `Docs/2026-08-22-airport-road-geocoding-and-map-layer.md` — the `extra_landmarks`
  mechanism this refresh exercised, and the `-L airport_road:` tippecanoe command.
* `Docs/2026-07-25-geocoder-handoff.md` — the two-step bundle build.
* `Submodules/iBurn-Data/data/2026/placement/README.md` — why nine camps have no polygon.

## Commits (nothing pushed)

| repo | hash | message |
|---|---|---|
| `Submodules/iBurn-Data/scripts/BlackRockCityPlanner` | `38d81ec` | Forward geocoder: resolve `"<time> & <time> <letter> Plaza"` |
| `Submodules/iBurn-Data` | `b87a0a1` | 2026 API refresh (Aug 27) + geocode audit |
| `Submodules/iBurn-Data` | `1c715ce` | 2026 media: fetch 1 thumbnail new in the Aug 27 API data |
| app repo | *(the commit adding this doc)* | Bump iBurn-Data: 2026 API refresh (Aug 27) + geocode audit |

## Expected Outcomes

* The shipped seed carries the placement as of three days before gates, and every camp
  pin in it is provably the point its map label is drawn at, inside the fence, near its
  published address.
* The only camps without a map pin are the five the API itself has not placed.
* `"<time> & <time> <letter> Plaza"` addresses typed into the app now resolve.
* `scripts/audit_camp_geocodes.js` is the standing check to re-run after every future
  refresh — it should keep printing `PASS`.
