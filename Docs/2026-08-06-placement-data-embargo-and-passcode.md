# 2026 Placement Data Refresh, Camp-Boundary Embargo, and New Passcode

**Date:** 2026-08-06 · **Branch:** `2026-updates` (main checkout, no worktree)
**Status:** DONE except items blocked on BMorg (see Remaining Work below).
The 2026 passcode was chosen and set (theme-derived; the plaintext is deliberately
NOT recorded here — this directory is public. It lives in the gitignored
`iBurn/BRCSecrets.m` hash and the `EMBARGO_PASSCODE_SHA256` GitHub secret).
Phase 3 PDF→geojson conversion is **out of scope** (separate program generates it;
we only handled the embargo gate + drop-in path).

## Results (2026-08-06)

- **Two-tier embargo implemented** (`586ee58`): camps + camp-hosted events unlock at
  `YearSettings.campLocationUnlock` (2026-08-23T07:01Z = 12:01 am PDT Sunday-before-gates,
  per the API ToS); art + art-located events unlock at `eventStart`. Missing plist key
  falls back to `eventStart` (fully-locked pre-tier behavior). 9 new `EmbargoTierTests`
  pass; `EventCalendarService` embargo closure is now per-occurrence.
- **Camp boundary layers embargo-gated** (same commit): `CampLayerVisibility.resolve`
  (pure, tested) drives `MapLayerManager`; `BaseMapViewController` re-resolves on
  `.BRCEmbargoDidClear`.
- **Passcode**: local `BRCSecrets.m` hash updated and the GitHub secret
  `EMBARGO_PASSCODE_SHA256` updated on iBurnApp/iBurn-iOS (unsalted SHA-256 of a
  dictionary phrase is trivially crackable, so neither plaintext nor hash belongs
  in this public repo).
- **Data refresh** (iBurn-Data `510d344`, app `21faf12`): API refetched Aug 6 — 330 art /
  1196 camps / 2430 raw events / 495 MVs — **all locations still null upstream** (0 geocoded;
  placement has NOT dropped to the API yet). bmorg GIS → `5c42af6` (adds DMZ2 CPN, moves
  toilets, trash fence tweak); mbtiles regenerated (955 features, streets renamed);
  geocoder rebuilt (60 CPNs incl. DMZ2); 13 new thumbnails; both PlayaDB seeds rebuilt.
  DMZ2 has no polygon — it renders as a text-labeled CPN at z15+ (no style change needed).
- **Sim verification** (fresh install, 2025 fixture geojson temporarily in Map.bundle):
  locked map hid camp outlines even with "Show Camp Boundaries (Always)" on; unlocking via
  More → the new passcode made the outlines appear live (no relaunch). Seed restore
  verified on-device: 330/1196/2361/4894/1580 rows. Fixture reverted afterward.

## Location Fixtures + Ship Guards (added later on 2026-08-06)

To validate location features before placement drops, `Submodules/iBurn-Data/
scripts/mock_locations.js` fabricates plausible locations from 2025 data
(camps name-matched with GPS translated by the Man-coordinate delta — 805/1196
matched; art name-matched or sampled from the 2025 GPS cloud; `--map-fixtures`
copies the 2025 camp outlines/labels geojson). See the iBurn-Data `CLAUDE.md`
"Location Fixtures" section for usage.

Guards so mock data can't ship (all verified by deliberately tripping them):
`MOCK_LOCATIONS` sentinel in APIData.bundle → `playa-seed` exits 1,
`iBurnTests/MockDataShipGuardTests` fails, deploy.yml "Refuse mock placement
data" step fails (also greps the geojson for previous-year fixture names).

Gotcha discovered: the legacy Yap importer (`BRCDataImporter
loadUpdatesFromData:`) crashes the app at launch if `update.json` contains any
non-`{file, updated}` top-level key, so the sentinel is a separate file, not an
update.json flag. Also, PlayaAPI decodes dates with strict `.iso8601` — no
fractional seconds in `updated` timestamps.

Verified in sim: mock apply → rebuild → JSON re-import → camp pins/callouts and
(fixture) outlines render after unlock; revert → guards green, submodule clean.

The real 2026 placement geojson will be generated from the placement PDF via
[jspolsky/brcMapTools](https://github.com/jspolsky/brcMapTools) (Phase 3).

## Remaining Work (blocked on BMorg / release timing)

1. **When placement drops in the API** (before Aug 23): re-run `fetch_and_geocode.js -y 2026`
   → expect real geocode counts → `playa-seed --fetch-media` → commit chain.
2. **When the placement PDF arrives** (~Aug 23 last year): generate
   `camp_outlines.geojson` / `camp_labels.geojson` with
   [jspolsky/brcMapTools](https://github.com/jspolsky/brcMapTools) → replace
   placeholders in `data/2026/Map/Map.bundle/` → commit. Embargo gate already in place.
3. Push submodule + app branches; publish `data/2026/` to public `iBurnApp/iBurn-Data`
   so `UPDATES_URL` OTA works; TestFlight build.
4. Distribute the new passcode to authorized early users (Placement etc.).

## High-Level Plan

Three workstreams for the run-up to gates (Aug 30):

1. **API data refresh** — BMorg placement is dropping; re-fetch 2026 API data (locations were all
   `null` in the 2026-07-18 refresh), regenerate geo/geocoder outputs and both PlayaDB seeds.
2. **Embargo the camp-boundary map layers** — last year `camp_outlines.geojson` /
   `camp_labels.geojson` rendered unconditionally (hardcoded in the MapLibre style, no
   `BRCEmbargo` check). Gate them properly *before* real 2026 placement geojson lands in
   `Map.bundle`, so a pre-gates App Store build can safely contain the data.
3. **New unlock passcode** — theme is **"Axis Mundi"** (cosmic tree / center of the world).
   Pick a passcode, update the SHA-256 hash locally and in CI.

### Recommended order

Phase 1 (embargo gating + passcode) is pure app code with no external dependencies — do it now.
Phase 2 (API re-fetch + seeds) runs as soon as placement is live in the API. Phase 3 (placement
geojson drop-in) waits on the camp-boundary PDF/QGIS export, which arrived ~Aug 23 last year.

---

## Phase 1a — Embargo-gate the camp-boundary layers

**Problem:** the layers are declared always-visible in the style JSON
(`Submodules/iBurn-Data/data/2026/Map/Map.bundle/styles/iburn-{light,dark}.json`, sources
`camp-boundaries` / `camp-labels` → `asset://iBurnData_iBurn2026Map.bundle/Map.bundle/*.geojson`).
The only runtime control is user settings in `iBurn/MapLayerManager.swift:16-48`
(`UserSettings.showCampBoundaries` / `showBigCampNames`), wired from
`iBurn/BaseMapViewController.swift:64-67` on style load. `BRCEmbargo` is never consulted —
`canShowLocationForObject:` (`iBurn/BRCEmbargo.m:56-69`) only gates annotations and address text.

**Change:**

- `MapLayerManager.swift`: layer visibility becomes
  `userSetting && BRCEmbargo.allowEmbargoedData()` for both `camp-boundaries` and
  `camp-labels-big`. Extract a small pure helper (e.g.
  `CampLayerVisibility.resolve(settings:embargoAllowed:)`) so the decision logic is unit-testable
  without MapLibre.
- `BaseMapViewController.swift`: observe `.BRCEmbargoDidClear` and re-run
  `updateAllLayers(mapView:)`. Both unlock paths already post it — passcode entry
  (`iBurn/EmbargoPasscodeViewModel.swift:102`) and geofence auto-unlock
  (`iBurn/BRCAppDelegate.m:318,331`). Time-based unlock self-sets the flag inside
  `allowEmbargoedData` (`iBurn/BRCEmbargo.m:40-53`), so the next style-load/layer-update pass
  picks it up automatically.
- Tests: unit tests for the visibility helper (locked/unlocked × setting on/off), added to
  `iBurnTests`.

**Why now:** the geojson ships inside the app bundle (SPM resource `iBurn2026Map`), not OTA.
Once real 2026 outlines exist we must ship a binary containing them before gates open —
without this gate the outlines would leak placement data immediately.

## Phase 1b — New embargo passcode ("Axis Mundi" theme)

Mechanism (`iBurn/BRCEmbargo.m:26-37`): unsalted SHA-256 compare against
`kBRCEmbargoPasscodeSHA256Hash` in gitignored `iBurn/BRCSecrets.m`, injected in CI from the
GitHub secret `EMBARGO_PASSCODE_SHA256` (`.github/workflows/{ci,deploy}.yml`). Generate with
`echo -n <passcode> | shasum -a 256`. The per-year defaults key
(`kBRCEntered2026EmbargoPasscodeKey`) is already year-stamped, so prior unlocks don't carry over.

Candidates were brainstormed from the "Axis Mundi" theme and one was chosen (kept out
of this public doc — see the session notes / GitHub secret).

Steps once chosen: update local `BRCSecrets.m` hash, update the `EMBARGO_PASSCODE_SHA256`
GitHub secret, verify unlock in the sim, coordinate distribution (Placement team) as in prior years.

## Phase 2 — API data re-fetch + seed regeneration (when placement is live)

Follow `Docs/2026-07-18-api-data-refresh.md`. Summary (run in
`Submodules/iBurn-Data/scripts/BlackRockCityPlanner`, needs `BMORG_API_KEY`; note
`api.burningman.org` is outside the sandbox allowlist — a failed run still clobbers
`update.json`, so always re-run to completion):

1. `node src/cli/fetch_and_geocode.js -y 2026 -l ../../data/2026/layouts/layout.json -o ../../data/2026/APIData/APIData.bundle`
   — this time expect non-null `location`/`location_string` and real geocode-success counts.
2. `node src/cli/generate_all.js -d ../../data/2026` — regenerate `data/2026/geo/*.geojson`.
3. Geocoder + tiles only if `layouts/layout.json` changed (unlikely; rebuilt Jul 25).
4. `swift run --package-path Packages/PlayaSeed playa-seed --fetch-media` — regenerates
   `iBurn/PlayaDB-2026.zip` + `iBurnWatch/PlayaDB-2026.zip`; commit any new thumbnails in
   `MediaFiles.bundle` (submodule).
5. Commit chain: BlackRockCityPlanner (if changed) → iBurn-Data → app repo.
6. Outstanding from July: push submodule `2026-updates` (local-only), and publish `data/2026/`
   to the public `iBurnApp/iBurn-Data` repo so `UPDATES_URL` OTA works.

## Phase 3 — 2026 placement geojson drop-in (when the PDF arrives)

Last year's provenance: hand-exported from the camp-placement PDF via QGIS
(`~/Downloads/placement_geojson/camp_outlines.geojson` 2.2 MB + `camp_labels.geojson` 48 MB,
dated 2025-08-23; committed to Map.bundle at 707 KB / 25.7 MB). LineString features,
`Layer: "Camp Outlines"`, CRS84. No generation script exists — 2026 placeholders in
`data/2026/Map/Map.bundle/` are empty FeatureCollections.

1. Obtain 2026 placement PDF → QGIS → export `camp_outlines.geojson` + `camp_labels.geojson`
   (document the QGIS steps in `Submodules/iBurn-Data` docs this time).
2. Replace the placeholder files in `Submodules/iBurn-Data/data/2026/Map/Map.bundle/`.
   Style JSON already references them; no app-code change needed. Consider coordinate-precision
   reduction on the labels file (25.7 MB shipped last year).
3. No seed rebuild needed (geojson isn't in PlayaDB). Commit submodule → app repo.
4. Verify in sim: locked → outlines hidden (Phase 1a gate); unlock via passcode → outlines render.

## Expected Outcomes

- App build containing real placement data can ship pre-gates without leaking locations.
- Passcode/geofence/date unlock all reveal camp boundaries live (no restart).
- Fresh 2026 data with real locations in both phone and watch seeds.

## Cross-References

- `Docs/2026-07-03-2026-year-update-plan.md` — annual rollover master checklist
- `Docs/2026-07-18-api-data-refresh.md` — fetch + seed runbook (LenientURL gotcha)
- `Docs/2026-07-13-official-2026-map-tiles.md` — tiles; notes placement placeholder status
- `Docs/2025-08-16-remove-camp-event-embargo.md` — 2025 embargo scope change (since re-enabled)
