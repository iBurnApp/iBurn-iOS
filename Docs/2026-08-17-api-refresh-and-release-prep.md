# 2026-08-17: API refresh (Aug 17), placement re-apply, seed regen, watch build bump

## High-Level Plan

Third 2026 data refresh of the season (after Aug 11 and Aug 16), plus two release-prep
loose ends.

**Problem**

1. The BMorg API keeps moving — camps drop out, art and events churn — and the shipping
   bundles were an Aug 16 snapshot. A fresh `fetch_and_geocode.js` run was made before this
   session started; its output was sitting uncommitted in `Submodules/iBurn-Data`.
2. `fetch_and_geocode.js` writes camp GPS from the **address geocoder** (street-intersection
   points). That overwrites the footprint-centroid pins `apply_placement.js` had installed, so
   every API refresh must be followed by a placement re-apply or 1,178 camp pins regress to
   corner-of-the-intersection coordinates.
3. The pre-baked PlayaDB seeds (`iBurn/PlayaDB-2026.zip`, `iBurnWatch/PlayaDB-2026.zip`) were
   built from the Aug 16 data and would have forced a slow first-launch re-import.
4. `CURRENT_PROJECT_VERSION` on the **iBurnWatch** target was still 109 while the app target had
   moved to 110 — the same drift that was fixed once already on Aug 11 (108 → 109). App and watch
   build numbers must match for a submission.

**Solution**

Run the standard post-fetch pipeline (`apply_placement.js` → `playa-seed`), fix the watch build
number, run both test suites, and commit the data submodule + pointer bump. No tile regeneration
(BMorg GIS submodule unchanged), no new placement drop (reused `data/2026/placement/`), nothing
pushed to any remote.

**Key changes**

| What | Where |
|---|---|
| Refreshed API bundles + placement re-applied + 1 new thumbnail | `Submodules/iBurn-Data` @ `7979d35` |
| Submodule pointer bump + this doc + checklist update | app repo |
| Watch `CURRENT_PROJECT_VERSION` 109 → 110 (Debug + Release) | `iBurn.xcodeproj/project.pbxproj` |
| Regenerated seeds (gitignored, not in any commit) | `iBurn/PlayaDB-2026.zip`, `iBurnWatch/PlayaDB-2026.zip` |

---

## Technical Details

### 1. Placement re-apply

```
cd Submodules/iBurn-Data
node scripts/apply_placement.js --year 2026
```

Inputs and results:

```
  placement: data/2026/placement/campsgeocodedwithborders.json (1191 records)
  polygons:  data/2026/placement/public_camps.geojson (1183 polygons)
  camps:     data/2026/APIData/APIData.bundle/camp.json (1187 camps)
  gps source: auto — polygon centroid (address geocode, then entrance centroid, as fallbacks)

=== Summary ===
Matched camps:              1186
Camps without placement:    1
Placement uids not in API:  5
Placement fields filled:    0
GPS from polygon centroid:  1178
GPS from address geocode:   2
GPS from entrance centroid: 0
Camps still without GPS:    7
Camps without any geometry: 9
Distinct GPS coordinates:   1180 (was 1180)
Outline features:           1178 -> Map.bundle/camp_outlines.geojson
Label features:             1178 -> Map.bundle/camp_labels.geojson
camp.json:                  updated (update.json timestamp bumped)
```

Polygon-source overlap: 1165 in both sources, 13 direct-export only, 0 OCR-only, 9 camps with no
outline at all (Westlandia, Baby Boomer Burners, SP Station, Flybynyte, Dusk, Black Rock Travel
Agency, Huǒ Fèng MV Support Camp, Yaass Daddy!, Kalos Scopeo). 5 placement records still have no
matching camp in the API roster (Tantra Temple, Club 40 at Cafe Calm, Crepes and Tonic, D'JUNGLE,
The Cage) — same five as Aug 16.

**Conflicts: 17, all resolved API-wins** (Aug 16 had 16; the new one is
`Renewables For Artists RAT HQ: location.exact_location`). The conflict list is Swan Forest (5
fields), ta-keel-ya or ta-heal-ya (3), Memento Mori (2), and single-field dimension/exact-location
disagreements on Altitude Lounge, Shenanigans, The Fluffy Cloud, LEGENDARY Playground of the Gods,
NumbSkulls, Renewables For Artists RAT HQ, Resonance. **Placement fields filled: 0** — the API now
serves every textual location field itself, so the drop's only remaining contribution is geometry.

**Idempotency verified**: a second run printed identical stats and
`camp.json: unchanged (no timestamp bump)`. `camp_outlines.geojson` and `camp_labels.geojson`
came out byte-identical to the Aug 16 committed versions (they never appeared in `git status`) —
the polygon inputs did not change, only camp.json's GPS needed restoring.

**Verification performed**

- All 1,178 camps that have a polygon have `gps_latitude`/`gps_longitude` **exactly equal** to
  their own feature in `camp_labels.geojson` (0 mismatches at 1e-9) — pin and label cannot drift.
- 1,180 camps have GPS; the 7 without have `null` coordinates, **not** `0,0` — no null island.
- No `MOCK_LOCATIONS` sentinel anywhere in `APIData.bundle`; no `2024_placement` string anywhere
  under `data/2026/`.
- `update.json` carries only `{file, updated}` per section, timestamps non-fractional ISO 8601
  with offset (e.g. `2026-08-17T20:56:47-07:00`).
- Outlines 1.9 MB / labels 311 KB, both non-empty, features carry `{uid, name}`.

### 2. Counts, Aug 16 (`4743806`) → Aug 17

| | Aug 16 | Aug 17 |
|---|---|---|
| camps | 1187 | 1187 |
| camps with GPS | 1180 | 1180 |
| camps with `location_string` | 1182 | 1182 |
| art | 334 | 334 |
| art with GPS | 334 | 334 |
| art at GPS `0,0` | 20 | 20 |
| events (raw rows) | 2635 | 2629 |
| unique event uids | 2630 | 2623 |
| duplicate event uids | 5 | 6 |
| event occurrences (raw) | 5316 | 5313 |
| mutant vehicles | 494 | 494 |
| `camp_outlines`/`camp_labels` features | 1178 | 1178 |

A quiet refresh: the roster is stable and only the event feed moved (6 rows removed, one more
duplicate uid, deduped at import as always).

**Art at `0,0` — 20 records, unchanged and shipped as-is.** Four are BMorg test rows
("deputy test ccc 6/4/26", "TRST Center Camp Mural 2026 spec", "spec's TRST of Walking in 2026",
"WG Test CC Canopy Walk-In"); the rest are real pieces the API has not placed yet
(Earth Guardians of Cryptometria Tree, Still Point…, Resonance, I am the Light. I remember,
Emergence, Scared Sacred, Golden Hour, The Art of Becoming, MinMax Curved Benches,
A Path thru (to Now), Mushrooms of Sirsasana, What the Eyes Cannot See…, ARI,
The Woman at the Core, Cryptomerian Calligraphy, Cryptomeria Kinship Series). Prior refreshes
shipped these unchanged and the display clamp handles them; parity kept deliberately rather than
introducing a new filtering behavior this close to submission.

### 3. Seed regeneration

```
swift run --package-path Packages/PlayaSeed playa-seed --fetch-media
```

(Sandbox disabled — the thumbnail host is outside the allowlist.)

```
==> Downloading 1 missing thumbnail(s)…
    Downloaded 1, failed 0.
==> Importing 2026 API data…
PlayaDB: Skipped 6 duplicate event UIDs during import
PlayaDB: Import completed in 0.41s
    Imported 334 art, 1187 camps, 5300 event occurrences, 494 mutant vehicles.
==> Extracting colours for 1581 thumbnail(s)…
    Cached 1580 colour rows.
==> Done
    art 334 · camps 1187 · events 5300 · mutant vehicles 494
    thumbnail colours: 1580
    thumbnails downloaded: 1
    archives: 2 × 3048 KB
```

New thumbnail `data/2026/MediaFiles/MediaFiles.bundle/a6BVI000000Re1N2AS.jpg` (referenced by
object `a1XVI00000FN9rZ2AT`'s row) committed in the submodule. Both zips written at 20:57, one
minute after `camp.json` (20:56) — confirmed newer than the bundle they were built from. Seed
occurrences 5300 vs 5313 raw: the 13-row gap is the 6 duplicate uids plus their occurrences,
the same shape as Aug 16 (5311 vs 5316).

**Legacy Yap seed re-harvested same day (session 2).** Followed Part C of
`Docs/2026-07-18-api-data-refresh.md` with one procedural fix now folded back into that doc:
the stale Aug 11 zip must be moved out of `iBurn/` *before* building, or the "fresh install"
restores the old seed and layers new JSON on top (upstream-deleted records would survive).
Fresh install of the zip-less build stabilized at **7083 `database2` rows** (~60 s, import
completes behind onboarding): 5559 `BRCEventObject`, 1187 `BRCCampObject`, 334 `BRCArtObject`,
3 `BRCUpdateInfo`. Zipped after terminate (`-wal` fully checkpointed at 0 B, hence 4.37 MB vs
Aug 11's 5.58 MB — no data loss) and dropped at `iBurn/iBurn-2026.zip` + the archival
`Submodules/iBurn-Data/data/2026/iBurn-2026.zip` (md5 `a60a5e98…`, both gitignored).
Restore-verified: rebuilt with the zip, fresh install restored all 7083 rows in ~15 s with no
JSON import.

### 4. Watch build number 109 → 110

`iBurn.xcodeproj/project.pbxproj`, the two iBurnWatch `XCBuildConfiguration` blocks (identified by
`INFOPLIST_KEY_WKApplication = YES` / `WKCompanionAppBundleIdentifier`):

```
-				CURRENT_PROJECT_VERSION = 109;
+				CURRENT_PROJECT_VERSION = 110;
```

All four `CURRENT_PROJECT_VERSION` occurrences in the project now read 110. Nothing else in the
pbxproj changed — `git diff --stat` reported exactly 2 insertions / 2 deletions, and no
`DEVELOPMENT_TEAM` flip was introduced by the build/test runs (checked before committing).

This is the second time the watch target lagged the app; the Aug 11 doc records the 108 → 109
fix. Bumping the app build without the watch is easy to miss because `agvtool`/manual bumps here
have historically only touched the app configs.

### 5. Tests

```
swift test --package-path Packages/PlayaDB 2>&1 | xcsift -f toon -w
→ status: success · passed_tests: 330 · failed_tests: 0 · errors: 0 (47.1s)

DEST='platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.5,arch=arm64'
xcodebuild test -workspace iBurn.xcworkspace -scheme iBurnTests -destination "$DEST" -quiet 2>&1 | xcsift -f toon -w
→ status: success · failed_tests: 0 · errors: 0 · 16 warnings (all "'X.o' has no symbols"
  libtool noise from the CocoaPods dependencies — pre-existing, unrelated to this change)
```

Ship-guard classes confirmed individually:

```
Executed 56 tests, with 0 failures  (EmbargoTierTests)
Executed  2 tests, with 0 failures  (MockDataShipGuardTests:
                                     testBundledAPIDataHasNoMockSentinel,
                                     testBundledCampGeojsonIsNotPreviousYearFixture)
```

### 6. Commits (local only — nothing pushed, `public` remote never contacted)

- `Submodules/iBurn-Data` `7979d35` — "2026 API refresh (Aug 17) + placement re-applied"
  (5 modified `APIData.bundle` JSONs + 1 new thumbnail; the two Map.bundle geojsons were
  byte-identical so they are not in the diff)
- app repo — submodule pointer bump `4743806` → `7979d35`, plus this doc and the
  `RELEASE_CHECKLIST.md` snapshot update
- app repo — watch `CURRENT_PROJECT_VERSION` 109 → 110, as its own commit

---

## Decisions

- **Placement re-apply is mandatory after every fetch, not optional.** `fetch_and_geocode.js`
  unconditionally rewrites camp GPS from the address geocoder, which silently regresses pins from
  footprint centroids to street-intersection points (where corner neighbours collide on one
  coordinate and the map has to fan them out). Running `apply_placement.js` immediately after the
  fetch is now the invariant; the `--gps-source auto` default guarantees the pin and the map label
  are literally the same coordinate array.
- **API text always wins over the placement drop.** 17 conflicts, all resolved to the API value.
  The drop is a snapshot of an older API state plus geometry; treating it as authoritative for
  text would resurrect stale addresses (e.g. Swan Forest's "F & 2:45" over the current "2:30 & F").
- **The 20 art records at `0,0` ship unchanged**, including BMorg's four test rows, matching Aug 11
  and Aug 16. Adding a filter now would be an untested behavior change days before submission, and
  the display clamp already handles the coordinates.
- **No tile regeneration**: the BMorg GIS submodule is unchanged since the Aug 11 Point 3 CPN
  work, so `generate_all.js` would be a no-op on geo outputs and tippecanoe was not needed.
- **7 camps ship without coordinates** rather than being placed at a guessed point. They have no
  polygon and an address the geocoder cannot resolve (Airport Road / plaza-corner strings). `null`
  is honest and keeps them off the map; `0,0` would put them in the Gulf of Guinea.

## Cross-References

- `Docs/2026-08-16-camp-boundary-embargo-tier.md` — the Aug 16 refresh log (same pipeline, the
  session where conflicts first appeared) and the camp-boundary embargo tier work.
- `Docs/2026-08-11-release-prep-2026.md` — Aug 11 refresh, the first watch build-number fix
  (108 → 109), and the release-prep sweep.
- `Docs/2026-08-09-merge-and-2026-placement-data.md` — origin of `apply_placement.js`, the two
  placement drops, and the polygon-centroid label fix.
- `Docs/2026-07-18-api-data-refresh.md` — the canonical refresh runbook, including the legacy Yap
  seed harvest (Part C) and the `BMORG_API_KEY` quoting failure mode.
- `Docs/RELEASE_CHECKLIST.md` — "First-2026-Build Status" snapshot, updated in this session.
- `Submodules/iBurn-Data/CLAUDE.md` — data-generation pipeline reference.

## Expected Outcomes

- A fresh install of build 110 restores a PlayaDB seed built from today's data — no on-device JSON
  re-import, no thumbnail colour computation on first launch (`needsImport` compares the bundled
  JSON's `update_info` against the seed's and finds them equal).
- Camp pins sit at their footprint centroids, coincident with their map labels, on both phone and
  watch.
- App and watch archive at 2026.0 (110) with matching build numbers.
- Embargo behavior is unchanged by this refresh: camp labels/bulk camp pins stay gated until
  `CampLocationUnlock`, art and art-located events until `EventStart`, and both ship guards are
  green against the newly bundled data.

## Remaining Work

- ~~Legacy Yap seed re-harvest~~ — done same day, see above (7083 rows, restore-verified).
- App Store Connect metadata entry, and a full archive on the release commit.
- Nothing has been pushed; the data submodule commit lives only in the local private clone.
