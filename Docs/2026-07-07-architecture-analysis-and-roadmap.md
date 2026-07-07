# Architecture Analysis & Roadmap (2026 → 2027)

**Date:** 2026-07-07 (Pacific)
**Branch:** `2026-updates`
**Status:** Analysis / planning document (no code changes)
**Related:** `2026-07-03-2026-year-update-plan.md`, `2026-07-03-playadb-audit-and-improvements.md`, `2026-07-03-watchos-mvp-plan.md`, `2026-01-25-playadb-migration-next-steps.md`, `2026-05-29-ai-guide-right-now-overhaul.md`

## High-Level Plan

This document captures (1) a factual snapshot of the current architecture, (2) the target
architecture we are migrating toward, (3) a **short-term plan for the 2026 event season**
(now → September 2026, ship-focused), and (4) a **longer-term plan for the 2027 cycle**
(post-event fall 2026 → summer 2027, migration-completion focused).

**The one-sentence story:** iBurn is mid-migration from a legacy
**Objective-C + YapDatabase + Mantle + UIKit** stack to a modern
**Swift + GRDB ("PlayaDB") + SwiftUI** stack; the map, detail screens, AI Guide, global
search, and the entire watch app already run on the modern stack, while the five list tabs
and the network data-update pipeline are the last major legacy holdouts. The 2026 season
plan is "ship what's proven, don't destabilize"; the 2027 plan is "finish the migration and
delete the legacy stack."

---

## 1. Current Architecture (verified snapshot, 2026-07-07)

### 1.1 Top-level layout

- `/iBurn/` — main app target: **43 `.m` + 48 `.h` Obj-C files, 206 Swift files**
- `/iBurnWatch/` — watchOS 26 app, 7 Swift files, fully modern (SwiftUI + PlayaDB + PlayaGeo)
- `/iBurnTests/` — 15 Swift test files
- `/Packages/` — local SPM: **PlayaDB** (~5.6k LOC), **PlayaAPI** (~1.1k LOC), **PlayaGeo** (~0.6k LOC)
- `/PlayaGeocoder/` — separate `.xcodeproj` framework (JS-bundle reverse geocoder), embedded in the app
- `/Submodules/` — `iBurn-Data`, `YapDatabase`, `DOFavoriteButton`, `ASDayPicker`, `PermissionScope`
- Shared schemes: `iBurn`, `iBurn (Mock Date)`, `iBurnTests`, `iBurnWatch`
- **Stale:** no `/PlayaKit/` directory exists anymore; `PlayaKit`/`PlayaKitTests` survive only as
  vestigial Pods xcconfig references in the pbxproj. The repo `CLAUDE.md` still describes both —
  needs a cleanup pass.

### 1.2 The two data stacks

**Legacy (YapDatabase + Mantle + Obj-C):**
- `BRCDatabaseManager`, `BRCDataObject` family (`BRCArtObject`/`BRCCampObject`/`BRCEventObject`/
  `BRCRecurringEventObject`), `BRCObjectMetadata`, `BRCMapPoint`/`BRCUserMapPoint`, `BRCEmbargo`.
  ~61 files still reference Yap.
- Serialization via Mantle 2.x.
- **Still load-bearing for:** the five default list tabs (via `YapTableViewAdapter`/
  `YapViewHandler`/`SortedViewController`), user map points + breadcrumbs on the map, and the
  **entire network update pipeline** (`BRCDataImporter` fetching `update.json` from
  `kBRCUpdatesURLString`, bundled zipped Yap DB seed).

**Modern (PlayaDB = GRDB 7.x + Codable via PlayaAPI):**
- `PlayaDB` protocol + `PlayaDBImpl` (2.5k LOC): async fetch/observe APIs, FTS5 search, R*Tree
  spatial indexes, day/hour-bucketed event observations, metadata (favorites/notes/last-viewed),
  thumbnail-color cache, user map pins, `importFromData`.
- Hardened by the 2026-07-03 audit: DatabasePool/WAL, write-free read paths, canonical FTS5
  external-content triggers, occurrence→parent-event metadata identity, narrowed observation
  regions, `DatabaseMigrator` (`v1-initial-schema`), 166 green tests, full 2026 import ~0.3 s.
- **Seeded from bundled JSON only** (`PlayaDBSeeder` → `BundleDataLoader` → `importFromData`);
  re-seeds when bundle `update.json` timestamps advance (`needsImport`). **No network update path.**
- DI via `@MainActor DependencyContainer` (single shared PlayaDB, providers, VM factories),
  reached through `BRCAppDelegate.dependencies`.

### 1.3 Who runs on what today

| Surface | Stack | Gating |
|---|---|---|
| Map annotations + filtering | PlayaDB (`FilteredMapDataSource`, `PlayaDBAnnotationDataSource`) | always on |
| Global search (map + lists) | PlayaDB FTS (`GlobalSearchViewModel`) | always on |
| Detail screen | PlayaDB SwiftUI (`DetailView`/`DetailViewModel`) | `useSwiftUIDetailView` default **true** all builds |
| AI Guide ("Right Now"), AI search, event summaries | PlayaDB + Apple Foundation Models | always on (hidden if no Apple Intelligence) |
| Nearby card on map | PlayaDB | always on |
| watchOS app (map/nearby/favorites/detail) | PlayaDB + PlayaGeo | always on (own DB, own seeder) |
| **Five list tabs** (Favorites, Nearby, Events, Art, Camps) | **YapDatabase UIKit by default**; PlayaDB SwiftUI alternates exist | `useSwiftUILists` — **DEBUG-only, default false** |
| User map pins / breadcrumbs | YapDatabase (`BRCUserMapPoint`) | always on |
| Network data updates | YapDatabase (`BRCDataImporter`) | always on |

**Bridging/dual-writes:** `DetailSubject` enum bridges `.legacy(BRCDataObject)` and PlayaDB
cases; favorites are dual-written Yap ↔ PlayaDB by uid (`DetailDataService.syncFavoriteToPlayaDB`,
`BRCDataObjectTableViewCell`) so hearts agree across stacks. ~11 files import both databases.

### 1.4 Map, watch, AI

- **Map:** MapLibre via SPM (`maplibre-gl-native-distribution`), offline MBTiles from
  `iBurn-Data` (2026 tiles generated 2026-07-03). Annotation content is PlayaDB; residual Yap
  connections in `MainMapViewController` exist only for user pins/breadcrumbs. Reverse geocoding
  via the `PlayaGeocoder` framework (JS bundle, year-hardcoded paths — annual checklist item).
- **watchOS:** standalone watchOS 26 app; SwiftUI `Canvas` vector map from bundled GeoJSON via
  `PlayaGeo` (MapLibre is wontfix on watchOS), own PlayaDB seeded from `iBurn2026APIData`,
  watch-local favorites. **No WatchConnectivity sync yet** (Phase 2 of the watch plan, pending
  an embedding decision).
- **AI:** all on-device Foundation Models (iOS 26+), gated on `canImport(FoundationModels)`.
  Single "Right Now" flow on the More tab (8 old workflows + chat deleted in May), semantic
  search wired into global search, AI event summaries on detail screens. All AI tools query
  PlayaDB.

### 1.5 Dependencies

- **CocoaPods (iOS-app-only, legacy-leaning):** YapDatabase (local podspec), Mantle,
  CocoaLumberjack, Anchorage, PureLayout, FormatterKit, BButton, TTTAttributedLabel, Appirater,
  CupertinoYankee, TUSafariActivity, KVOController, Onboard, JTSImageViewController,
  UIImageColors, LicensePlist + 4 local-podspec submodules.
- **SPM remote:** GRDB.swift 7.6.1+, MapLibre, firebase-ios-sdk, Siren, Zip.
- **SPM local:** PlayaDB, PlayaAPI, PlayaGeo, iBurn-Data (`iBurn2026APIData`/`Map`/`MediaFiles`).
- **Dual-sourced smells:** two databases in production; two geo helpers (`PlayaGeocoder`
  xcodeproj vs `PlayaGeo` package); Mantle vs Codable; residual `MGL` naming from Mapbox days.

### 1.6 Data pipeline & embargo

- Yearly rollover to 2026 is **complete and verified** (see `2026-07-03-2026-year-update-plan.md`):
  new city geometry (Man at 40.783242,-119.207871, streets Ararat…Kundalini, fence 8287'),
  2026 API data (321 art / 1201 camps / 2140 events / 499 MVs), regenerated tiles + geocoder,
  `iBurn2026*` package renames, `MARKETING_VERSION` 2026.0.
- All 2026 locations are **null (embargoed)** until gates; `BRCEmbargo` gates location display in
  both stacks; 2026 passcode hash still pending from BMorg.
- Event dates: **Sun Aug 30 – Mon Sep 7, 2026** (Man Burn Sep 5, Temple Burn Sep 6).

---

## 2. Target (Future) Architecture

The end-state we are converging on, most of which already exists in embryo:

1. **Single database: PlayaDB (GRDB).** One SQLite file, one import path, one observation
   layer. YapDatabase, Mantle, and the `BRC*Object` Mantle models deleted. User data
   (favorites, notes, map pins, breadcrumbs, visit lists) lives in GRDB tables.
2. **Single data pipeline.** A `PlayaAPI`-based network updater (Codable models, delta-aware
   `importFromData`) replaces `BRCDataImporter`; the bundled-zip Yap seed and dual seeding
   disappear. The same pipeline serves iPhone and (via reseed or connectivity) watch.
3. **SwiftUI-first UI.** List tabs, detail, search, AI, onboarding, and settings in SwiftUI;
   UIKit retained only where it earns its keep (MapLibre host VC, tab controller shell).
   `YapTableViewAdapter`/`SortedViewController` and the legacy list VC family deleted.
4. **Protocolized services + DI everywhere** (already the house style): `PlayaDB`,
   `LocationProvider`, `MediaAssetProviding`, `PreferenceService` behind protocols built by
   `DependencyContainer` factories.
5. **SPM-only dependencies.** CocoaPods retired; the surviving legacy pods either dropped with
   the UIKit screens that use them or replaced by SPM equivalents. `PlayaGeocoder` either
   absorbed into `PlayaGeo` (Swift port of the radial geocoding math) or repackaged as SPM.
6. **Multi-target platform story:** iPhone app + standalone watch app sharing
   PlayaAPI/PlayaDB/PlayaGeo, with WatchConnectivity syncing user metadata deltas; room for
   widgets/complications ("gates open" countdown, next favorited event) on the same packages.
7. **AI as a first-class but optional layer:** Foundation Models tools over PlayaDB only, one
   immediacy-first flow, degrading gracefully on unsupported hardware.

Architecture rule of thumb going forward: **new persistence is GRDB/Codable, new UI is
SwiftUI, new services are protocol + Impl behind the container** — legacy code is only
touched to delete it or to bridge it out.

---

## 3. Short-Term Plan — 2026 Season (now → mid-September 2026)

Guiding principle: **the burn is in 8 weeks; ship what's proven.** No structural migration
work lands between now and the event. The season is a data-cadence + polish exercise, same
shape as 2025 (June/July structural pass → August point releases).

### 3.1 Release engineering (July)

- [ ] Commit/land the `2026-updates` branch work (year flip + PlayaDB audit are done and
      verified; watch MVP phases 0/1/3/4 done) and get a `2026.0` TestFlight beta out early
      so the season cadence has a baseline.
- [ ] Decide watch app shipping scope for 2026: **ship standalone** (map/nearby/favorites
      work today, watch-local favorites) and defer WatchConnectivity sync unless it lands
      comfortably by early August. A standalone watch app is a complete, honest v1.
- [ ] Verify Siren/App Store metadata, screenshots for the 2026 city, privacy manifest
      currency.

### 3.2 Feature-flag decisions (decide by ~Aug 1)

- **`useSwiftUIDetailView` (default true):** already the shipped default — keep.
- **`useSwiftUILists` (DEBUG-only, default false):** the SwiftUI list stack now covers all
  five tabs and PlayaDB is audited/fast, but it has never survived a public beta.
  **Recommendation:** promote the flag from `#if DEBUG` to a hidden/internal toggle in
  release builds, run it **on** in TestFlight betas through July, and make the go/no-go call
  ~Aug 1. Default **off** for the App Store release unless beta telemetry/crash data is
  clean — legacy lists are battle-tested and the cost of dual stacks for one more season is
  already paid.
- **Known blocker to check before any flip:** PlayaDB is bundle-seeded only. The August
  data refreshes reach PlayaDB **only via app updates** (bundle reseed through
  `needsImport`), while Yap gets them over the air via `update.json`. If lists ship on
  PlayaDB, on-playa users without app-store access would see stale data the moment we push
  an OTA-only update. Either (a) keep lists on Yap for 2026 (default recommendation), or
  (b) land the minimal "PlayaDB network refresh" — reuse `BRCDataImporter`'s download, then
  feed the fetched JSON through `importFromData` — which is a small, testable bridge but
  still new plumbing in August. Decide deliberately, not by default.

### 3.3 August data cadence (deferred items from the rollover plan, as data lands)

- [ ] **2026 embargo passcode hash** from BMorg → `BRCSecrets.m`; re-confirm embargo policy
      (2025 relaxed camp/event embargo to art-only — decide 2026 stance).
- [ ] **API re-fetch with locations** once BMorg unlocks GPS (`fetch_and_geocode.js -y 2026`,
      needs `BMORG_API_KEY`); add URL sanitization to the fetch script (the 4 malformed-URL
      records found in July would crash strict `URL` decoding again on re-fetch).
- [ ] **Official GIS tiles** when `innovate-GIS-data` publishes 2026 (redo tippecanoe per
      `2025-07-19-map-tiles-official-data.md`; remember `-t "$TMPDIR"` under sandbox).
- [ ] **Placement geojson** → regenerate `camp_labels.geojson`/`camp_outlines.geojson`
      (currently shipped as empty FeatureCollections).
- [ ] **Media refresh + audio tour** (thumbnails already done — 1574/1574; audio arrives
      late season).
- [ ] Each data drop = a point release (`2026.1`, `2026.2`, …), matching the 2025 rhythm.
      Remember both bundles feed *two* databases until the migration completes: bundled-zip
      Yap seed **and** JSON for PlayaDB must both be regenerated per drop.
- [ ] Annual-checklist gotchas already logged: geocoder year-hardcoded paths
      (`BlackRockCityPlanner/src/geocoder/index.js`, `PlayaGeocoder.xcodeproj`), test-fixture
      re-dating into the event window, pbxproj `DEVELOPMENT_TEAM` dirtying.

### 3.4 Stability/paper-cut budget (July, small and reversible only)

- [ ] Watch follow-ups from the 07-03/07-06 sessions (e.g. the PlayaDB spatial-index
      UPDATE-trigger gap noted in the watch plan; off-playa blank-map fix landed 07-06).
- [ ] Favorites dual-write spot-check on device (Yap ↔ PlayaDB agreement after the metadata
      identity fix).
- [ ] Fresh-install + upgrade-install passes via the drive-app flows before each release;
      keep `references/flows.md` current.
- [ ] AI Guide sanity pass on-device (iOS 26 hardware) — it ships always-on for capable
      devices.

**Explicit non-goals for the season:** list-tab migration flip (unless beta-proven), PlayaDB
network ingestion (unless chosen in 3.2), Yap user-data migration, CocoaPods exit, any
schema migrations beyond additive ones.

---

## 4. Longer-Term Plan — 2027 Cycle (Oct 2026 → Aug 2027)

Goal: **enter the 2027 rollover with one database, one pipeline, and no Obj-C data layer.**
Sequenced so each phase ships independently behind the existing flag infrastructure and shrinks the
legacy surface monotonically.

### Phase 1 — Unify data ingestion on PlayaDB (Oct–Dec 2026)

The keystone: everything else is blocked on PlayaDB being update-capable.
- Build `PlayaUpdateService` (protocol + Impl in `Packages/PlayaDB` or a thin app service):
  fetch `update.json` + per-type JSON via `PlayaAPI` Codable models, diff timestamps against
  `UpdateInfo`, call `importFromData` per changed type. Reuse the existing
  `kBRCUpdatesURLString` endpoint and background-fetch hooks.
- Import semantics to verify/extend: deletion handling (records removed upstream), partial
  imports, embargo-safe location updates, preserving `ObjectMetadata` across re-imports
  (already keyed by uid — add regression tests).
- Run it **in parallel with** `BRCDataImporter` for a beta cycle (both stacks stay fresh),
  then make PlayaDB the source of truth and let Yap go stale behind the scenes.

### Phase 2 — Lists to SwiftUI by default; user-data migration (Jan–Mar 2027)

- Flip `useSwiftUILists` default **on** for all builds; keep the legacy stack one release as
  a kill-switch, then delete: the five legacy list VCs, `YapTableViewAdapter`,
  `YapViewHandler`, `SortedViewController`, `ListCoordinator`, the XIB cell family.
- One-time migration of Yap user data into GRDB: favorites + notes + last-viewed (mostly
  already dual-written), **user map pins & breadcrumbs** (new GRDB tables; port
  `BRCUserMapPoint` map layer to `UserMapPin`), visit lists. Migration runs once at launch,
  idempotent, covered by tests with a fixture Yap DB.
- Remove the favorites dual-write once migration ships.

### Phase 3 — Delete the legacy core (Apr–May 2027)

- With no UI or pipeline consumers, delete `BRCDatabaseManager`, `BRCDataImporter`,
  `BRCDataObject` family, `BRCObjectMetadata`, Mantle usage, the bundled-zip Yap seed, and
  the YapDatabase pod/submodule. Port stragglers (`BRCEmbargo`, `BRCDetailViewController`
  off-path, remaining categories) to Swift as encountered.
- CocoaPods exit: with the legacy UIKit screens gone, most pods lose their reason to exist.
  Replace survivors with SPM (CocoaLumberjack has SPM; UIImageColors et al. as needed) and
  delete the Podfile. Single-package-manager builds also simplify the watch/CI story.
- Consolidate geo: port the reverse geocoder into `PlayaGeo` (Swift radial math — the
  layout.json numbers are all we need) or wrap the JS bundle as an SPM target; delete
  `PlayaGeocoder.xcodeproj` and its year-hardcoded path gotcha.

### Phase 4 — Platform expansion on the unified stack (May–Jul 2027)

- **WatchConnectivity metadata sync** (the deferred watch Phase 2): favorites/notes deltas
  keyed by `updated_at`, last-writer-wins; watch data refresh piggybacks on Phase 1's
  update service.
- **Widgets/complications:** gates countdown, next favorited event, sunrise/sunset — cheap
  once PlayaDB is the single source (shared app group or per-target seed).
- Evaluate: Live Activities for favorited events, Siri/App Intents ("what's happening now"),
  deeper AI Guide iterations — all now single-stack features.
- 2027 rollover itself (June–July 2027) should then be *only* the data/geometry checklist —
  no dual-database bookkeeping.

### Continuous

- Keep `CLAUDE.md`/`AGENTS.md` truthful as the migration deletes things (PlayaKit references
  are already stale today).
- Test posture: PlayaDB package tests are the strongest suite (166) — every phase above adds
  its regression tests there or in `iBurnTests`; keep `EXPLAIN QUERY PLAN` tests honest as
  queries evolve.

---

## 5. Risks & Open Questions

1. **Dual-database drift** is the top short-term risk: two seeds, two update stories, dual-written
   favorites. Every August data drop must feed both until Phase 1 lands. Mitigation: the
   release checklist in §3.3, plus the on-device favorites spot-check.
2. **`useSwiftUILists` go/no-go** (§3.2) is the season's only real architecture decision —
   the OTA-staleness constraint is the deciding factor, not UI polish.
3. **Watch scope creep:** WatchConnectivity is tempting but the standalone story is complete;
   defer to Phase 4 unless trivially done.
4. **Foundation Models availability:** AI features are iOS 26 + Apple Intelligence hardware
   only; the graceful-hiding paths (`AISearchServiceFactory` returning nil,
   `makeAIGuideViewModel()` nil) must stay tested as the OS evolves through betas.
5. **Yap user-data migration fidelity** (Phase 2): breadcrumbs/visit lists have no dual-write
   today; the one-time migration is the only shot — needs fixture-DB tests before shipping.
6. **Open:** 2026 embargo policy (art-only vs full), 2026 passcode timing, whether BMorg
   publishes 2026 GIS/placement in time, `.gitmodules` private/public flip decision.

## Expected Outcomes

- **September 2026:** a stable 2026.x release train — proven legacy lists (or beta-proven
  SwiftUI lists), PlayaDB-powered map/detail/search/AI, a standalone watch app, fresh data
  through the August cadence.
- **August 2027:** single GRDB database and single update pipeline, SwiftUI list tabs, no
  YapDatabase/Mantle/CocoaPods, geo consolidated, watch synced — and a 2027 rollover that is
  purely a data exercise.
