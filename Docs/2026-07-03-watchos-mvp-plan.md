# watchOS MVP App — Plan

Date: 2026-07-03 (Pacific)
Branch: `2026-updates`
Status: Phases 0, 1, 3, 4 + watch-local favorites complete and sim-verified.
Remaining: Phase 2 WatchConnectivity sync (needs embedding decision), plus
follow-ups. See "Phase 3/4 Results" for the spatial-index UPDATE-trigger gap
found in PlayaDB.

## High-Level Plan

Build a **standalone-capable watchOS 26 app** for iBurn. MVP pillars, in order:

1. **Map + compass (P0):** show yourself on an offline map of Black Rock City with
   compass rotation (heading-up mode) and a calibration hint when heading accuracy
   degrades.
2. **Favorites (P1):** full favorites list on the watch, synced bidirectionally with
   the phone via WatchConnectivity.
3. **Nearby (P1):** list of closest art/camps sorted by GPS distance (list-first, not
   a card like the phone's map).
4. **POI navigation (P1):** from a camp/art detail, a navigation view showing the POI
   and your location on the map in compass mode with distance/bearing readout.

Development style: **preview-driven** — every view ships with `#Preview`s backed by
mock data / in-memory PlayaDB, validated via `mcp__xcode__RenderPreview` before
on-device runs.

## Decisions (user-confirmed 2026-07-03)

1. **Map rendering: custom SwiftUI Canvas vector map.**
   MapLibre Native does not support watchOS — upstream issue
   [maplibre-native#12](https://github.com/maplibre/maplibre-native/issues/12) is
   marked *wontfix*, and the SPM xcframework (`maplibre-gl-native-distribution`)
   ships iOS slices only. Instead we draw BRC directly from the bundled GeoJSON
   (streets/fence/plazas/toilets, ~300 KB) in a SwiftUI `Canvas`. Fully offline,
   trivially rotatable (affine transform we own), theme-able, preview-friendly.
   Rejected alternatives: pre-rendered raster snapshot (blurry, no dynamic layers),
   building MapLibre for watchOS from source (wontfix upstream, unproven
   Metal/memory profile on watch, permanent fork).
2. **Data: full standalone PlayaDB seed on watch.**
   Bundle the same `iBurn2026APIData` JSON (3.4 MB) and run the existing
   `PlayaDBSeeder` + GRDB on-watch. Skip MediaFiles/thumbnails. The watch works 100%
   without the phone; WatchConnectivity syncs only the tiny favorites/metadata
   deltas. Rejected: favorites-only synced subset (watch useless until first sync,
   no browsing/nearby).
3. **Favorites access: top-level in-app list for MVP.** WidgetKit complication is a
   follow-up, not MVP.

## Research Facts (2026-07-03)

### Platform / APIs
- **MapLibre:** no watchOS support (wontfix; iOS-only xcframework slices).
- **Compass:** `CLLocationManager.startUpdatingHeading()` is available on watchOS 6+;
  every watchOS 26 device (Series 6+/SE2+/Ultra) has compass hardware.
  `locationManagerShouldDisplayHeadingCalibration` (system figure-8 UI) is
  **iOS-only** — on watchOS we monitor `CLHeading.headingAccuracy` (negative =
  uncalibrated) and show our own "wave your wrist in a figure-8" hint.
- **GRDB:** supports watchOS. **MapKit types** (`MKCoordinateRegion` used by
  `FilterRegion`) exist on watchOS.

### Repo facts (from exploration)
- `iBurn.xcodeproj` has exactly two targets (`iBurn`, `iBurnTests`). No extension
  targets exist yet. CocoaPods covers the iOS app only (legacy Obj-C/UIKit pods,
  iOS-only) — the **watch target must be SPM-only**.
- SPM local packages: `Packages/PlayaAPI` (pure Foundation, models +
  `BundleDataLoader`), `Packages/PlayaDB` (GRDB 7.x). Both declare
  `platforms: [.iOS(.v16), .macOS(.v13)]` — need `.watchOS` added. Same for
  `Submodules/iBurn-Data/Package.swift` (resource bundles `iBurn2026APIData` 3.4 MB,
  `iBurn2026Map`, `iBurn2026MediaFiles`).
- Seeding: `DependencyContainer` → `PlayaDBSeeder.seedIfNeeded()` →
  `BundleDataLoader.load*(from: .brc_dataBundle)` → `PlayaDBImpl.importFromData`
  (~0.3 s on iPhone sim). Reusable as-is on watch.
- Nearby: no explicit `fetchNearby` API — a bounding-box `FilterRegion` on
  `ArtFilter`/`CampFilter`/`EventFilter` hits the R*Tree
  (`spatial_index`/`event_occurrence_rtree`); distance sort is client-side
  (`NearbyViewModel`, 500 m default region).
- Favorites: `object_metadata` table (`object_type`, `object_id`, `is_favorite`,
  `user_notes`, timestamps incl. `updated_at`). **No sync mechanism exists anywhere**
  (zero hits for WatchConnectivity/CloudKit).
- GeoJSON inventory (`Submodules/iBurn-Data/data/2026/geo/`): `streets.geojson`
  244 K, `polygons.geojson` 176 K, `toilets.geojson` 60 K, `points.geojson` 8 K,
  `fence.geojson`/`dmz.geojson` ~1–2 K, `outline.geojson` 776 K (big — simplify or
  skip; fence suffices for the boundary). These raw files are *not* currently
  bundled at runtime (the phone uses `map.mbtiles`); the watch will bundle the geo
  files it needs.
- iOS deployment target 16.6; local packages swift-tools 5.9.

## Architecture

### New pieces
- **`Packages/PlayaGeo`** (new local SPM package, platforms iOS/watchOS/macOS):
  - GeoJSON parsing into typed geometry (polylines/polygons/points).
  - Local planar projection (equirectangular around city center — fine at BRC
    scale), `MapCamera` (center/zoom/rotation) math, viewport culling.
  - `PlayaMapView`: SwiftUI `Canvas` renderer (streets, fence, toilets, POI dots,
    user location dot + heading cone). Pure SwiftUI → previewable on any platform,
    unit-testable camera/projection math via `swift test` on macOS.
  - Reason it's a package: preview-driven dev + fast mac-side tests without
    building the watch target.
- **`iBurnWatch` target** (watchOS app, SwiftUI lifecycle, watchOS 26, SPM deps
  only: PlayaDB, PlayaAPI, PlayaGeo, iBurn2026APIData + bundled geo resources).
  Embedded in the iOS app (single App Store listing), but `WKRunsIndependentlyOfCompanionApp`
  so it runs standalone.
  - `WatchDependencyContainer`: builds PlayaDB at watch Documents path, runs
    `PlayaDBSeeder` (shared logic — may need a small move of `PlayaDBSeeder` into a
    package or a watch copy; prefer moving seeding into `PlayaDB`/`PlayaAPI` so both
    apps share it).
  - `LocationService`: CLLocationManager wrapper exposing async streams for
    location + heading, `headingAccuracy`-based calibration state.
  - Root navigation: Map (launch screen) / Favorites / Nearby.
- **`WatchSync` (WatchConnectivity bridge)**, both sides:
  - Payload: favorites snapshot `[(objectType, objectId, isFavorite, updatedAt)]`
    (+ embargo-unlocked flag) via `updateApplicationContext` (last-state) plus
    `transferUserInfo` for reliability on individual toggles.
  - Merge: per-item last-writer-wins on `updated_at`. New PlayaDB API:
    `applyFavoriteSync(_ items:)` that only writes rows whose incoming
    `updatedAt` is newer (column-limited updates, consistent with region-narrowed
    observations).
  - Phone side: a `WatchSessionManager` in `DependencyContainer` observing
    favorites changes and pushing; applies incoming watch toggles.

### Embargo on watch
Camp/art locations are restricted until gates open. MVP: watch defaults to
restricted; the phone syncs its embargo-unlocked state over WatchConnectivity
(no passcode entry UI on watch). Until unlocked, map shows city geometry + toilets
+ user location but no camp/art pins; nearby rows show "Location Restricted" like
the phone lists.

## Phases

### Phase 0 — Foundations (build plumbing)
1. Add `.watchOS("26.0")` (or the tools-supported spelling) to `platforms` in
   `Packages/PlayaAPI`, `Packages/PlayaDB`, `Submodules/iBurn-Data` Package.swift.
   Verify `PlayaDB` compiles for a watchOS destination (watch-sim build of a tiny
   consumer, or `xcodebuild -destination 'generic/platform=watchOS Simulator'`).
2. Create `iBurnWatch` watchOS app target. Hand-editing pbxproj is error-prone —
   use a Ruby script with the `xcodeproj` gem (already present via CocoaPods) to
   add the target, build settings (SDKROOT watchos, `WATCHOS_DEPLOYMENT_TARGET=26.0`,
   `TARGETED_DEVICE_FAMILY=4`, bundle id `com.trailbehind.iBurn2010.watchkitapp`),
   SPM product links, and the Embed Watch Content phase on `iBurn`.
3. Smoke: "Hello Playa" watch app builds + runs in watch simulator; PlayaDB seeds
   on-watch (verify row counts via simctl container + sqlite3, same as drive-app
   skill).

### Phase 1 — Map + compass (P0)
1. `PlayaGeo` package: GeoJSON decode, projection, `MapCamera`, culling; unit tests
   for projection/camera math.
2. Bundle trimmed geo resources (streets, fence, toilets, points; skip/simplify
   outline.geojson).
3. `PlayaMapView` Canvas renderer + previews (mock geometry, fixed camera states:
   north-up, rotated, zoomed).
4. Watch `MapScreen`: user dot + heading cone, Digital Crown zoom, drag pan,
   north-up ⇄ heading-up toggle, recenter button, calibration hint banner when
   `headingAccuracy < 0` or > threshold.
5. Validate previews via RenderPreview; then on watch simulator with simulated
   location (40.7864, -119.2065).

### Phase 2 — Favorites (P1)
1. Move/share seeding so watch reuses it; watch `FavoritesScreen` (name, type
   emoji, distance; tap → detail). Previews with in-memory PlayaDB
   (`createInMemoryPlayaDB()` + mock favorites).
2. `applyFavoriteSync` API + tests in PlayaDBTests (LWW merge semantics).
3. WatchConnectivity bridge both sides + embargo flag sync. Manual end-to-end:
   favorite on phone sim → appears on watch sim (paired sims), and reverse.

### Phase 3 — Nearby (P1)
1. `NearbyScreen`: reuse `FilterRegion` bounding-box observe + client distance
   sort (mirror `NearbyViewModel` shape, simplified). Rows: type emoji, name,
   distance, relative bearing arrow.
2. Previews with mock rows at known offsets; sim validation with simulated
   location.

### Phase 4 — POI detail + navigation (P1)
1. `DetailScreen` (camp/art): name, description, location string (embargo-aware),
   favorite toggle (heart), "Navigate" button.
2. `NavigationScreen`: `PlayaMapView` fit-to-bounds(user, POI), compass mode
   forced on, distance + bearing readout, straight-line path.

### Follow-ups (explicitly NOT MVP)
- WidgetKit complication (favorites / next favorited event) — needs App Group.
- Events on watch (data is seeded already; UI deferred).
- Notifications/local reminders for favorited events; watch-side embargo passcode
  entry; breadcrumb trails.

## Phase 0 Results (2026-07-03)

- watchOS 26.5 platform was a stub in Xcode 26.5 — downloaded via
  `xcodebuild -downloadPlatform watchOS` (required before any watch destination
  resolves; `-showsdks` listing the SDK is not sufficient).
- Added `.watchOS(.v10)` to `Packages/PlayaDB`, `Packages/PlayaAPI`, and
  `Submodules/iBurn-Data` Package.swift (submodule commit `6bc923e`).
- Created `iBurnWatch` target via `xcodeproj` gem script (not hand-edited pbxproj):
  standalone watch app (`INFOPLIST_KEY_WKApplication`/`WKWatchOnly`, generated
  Info.plist, bundle id `com.trailbehind.iBurn2010.watchkitapp`,
  `WATCHOS_DEPLOYMENT_TARGET=26.0`, `TARGETED_DEVICE_FAMILY=4`), SPM products
  PlayaDB + PlayaAPI + iBurn2026APIData, shared scheme `iBurnWatch`.
  **Deliberately NOT embedded in the iOS app target yet** — embedding would make
  every iOS/CI build require the watchOS platform. Revisit when WatchConnectivity
  sync (Phase 2) needs real pairing.
- Watch sources: `iBurnWatch/iBurnWatchApp.swift` (creates PlayaDB via
  `createPlayaDB()`), `iBurnWatch/ContentView.swift` (Phase 0 smoke screen:
  seeds from `iBurn2026APIData.bundle` via `BundleDataLoader` +
  `importFromData` when `getUpdateInfo()` is empty, then shows counts; includes
  an in-memory-DB `#Preview`).
- **Verified on Apple Watch Ultra 3 (49mm) sim (watchOS 26.5, UDID
  `73FEA1F2-69EB-4A7E-AAD1-3613B88D8F30`):** app launches, seeds on-watch, shows
  `321 art / 1201 camps` — matching the 2026 dataset counts from the iPhone app.
- Build command:
  `xcodebuild -workspace iBurn.xcworkspace -scheme iBurnWatch -destination 'generic/platform=watchOS Simulator' build 2>&1 | xcsift -f toon -w`

## Phase 1 Results (2026-07-03)

- **`Packages/PlayaGeo`** created (iOS 16 / macOS 13 / watchOS 10, zero deps):
  - `GeoJSON.swift` — FeatureCollection decoder into `GeoFeature`/`GeoGeometry`
    with its own `GeoCoordinate` (no CoreLocation dependency; null-geometry
    features skipped).
  - `PlayaProjection.swift` — equirectangular meters around The Man; +x east,
    +y south (screen-down) so north-up needs no flip. WGS84 local scale factors;
    sub-meter accurate at city scale.
  - `MapCamera.swift` — center/metersPerPoint/headingDegrees + world→screen
    `CGAffineTransform`, rotation-aware `centerAfterPan`, `fitting(points:)`.
  - `PlayaMapView.swift` — SwiftUI Canvas renderer: plaza fills, streets with
    true-meter widths, dashed fence, toilets (zoom-gated), `MapMarker`s, user
    dot + heading cone; light/dark styles via colorScheme.
  - 18 tests green (`swift test`), including decoding the real 2026 geo files and
    camera-math directional assertions. One test expectation was initially wrong
    (pan under rotation): facing east means the screen-bottom is west, so
    dragging up moves the center −x; code was correct.
- Watch target wiring (2nd xcodeproj-gem script): PlayaGeo local package +
  product, GeoJSON resources referenced **in place** from
  `Submodules/iBurn-Data/data/2026/geo/` (points/streets/fence/toilets/polygons —
  no duplication; year rollover means re-pointing these refs),
  `INFOPLIST_KEY_NSLocationWhenInUseUsageDescription`.
- Watch UI: `LocationService` (async location + heading, `needsCalibration` when
  headingAccuracy < 0 or > 45° — watchOS can't summon the system figure-8 UI, so
  MapScreen shows a hint banner), `MapScreen` (crown zoom 50→0.8 m/pt, drag pan
  honoring rotation, heading-up toggle, follow-user with recenter, The Man /
  Center Camp markers), root vertical-page TabView (Map, DB-status page).
- **Verified on Ultra 3 sim:** location alert (buttons require swiping the alert
  up), city renders (pentagon fence, radial grid, plazas, user dot at simulated
  BRC location, markers, controls); compass toggle flips state without crash
  (sim has no compass hardware). iOS app still builds after pbxproj changes.

## Phase 3/4 Results + watch-local favorites (2026-07-03)

- Root restructured from paging TabView to **NavigationStack**: `.verticalPage`
  paging uses crown + vertical swipes, which the map already claims for zoom/pan.
  Map is fullscreen root; toolbar buttons (topBarLeading "Nearby",
  topBarTrailing "Favorites") navigate. Old ContentView smoke page removed;
  seeding moved to `WatchSeeder.seedIfNeeded` run from an app-level `.task`.
- New screens (all in `iBurnWatch/`): `NearbyScreen` (region-filtered
  `fetchArt`/`fetchCamps` around user, client distance sort, 30-row cap,
  embargo-aware empty state), `FavoritesScreen` (`getFavorites()`, distance
  sort), `DetailScreen` (favorite toggle via `setFavorite`, description,
  Navigate link gated on `hasLocation`), `NavigationScreen` (PlayaMapView fit to
  user+target, heading-up when compass exists, live distance/bearing readout,
  calibration hint).
- **Sim-verified end-to-end** (test GPS injected into 3 camps via sqlite3, app
  uninstalled afterward to purge): Nearby sorted 309 m / 590 m / 1.1 km →
  detail → Add Favorite → `object_metadata` row `camp|<uid>|1` → Navigate view
  showed target marker + user dot + "309 m · 55°" → Favorites listed the camp.
- **PlayaDB finding (FIXED same day):** `spatial_index` R*Tree was only
  maintained by import-time rebuild + insert/delete triggers — UPDATE of gps
  columns left it stale, so region queries missed rows whose GPS changed
  in-place (would have bitten when the embargo drop arrives as an update).
  Fixed with `*_spatial_update` triggers (art/camp/event; delete-then-
  conditionally-reinsert keyed via the mapping table, not last_insert_rowid)
  plus `event_occurrence_rtree_event_update` refreshing the denormalized
  occurrence R*Tree when an event's GPS changes. Trigger generation refactored
  into a data-driven loop; existing DBs pick the new triggers up on next open
  (CREATE TRIGGER IF NOT EXISTS). Covered by
  `SpatialIndexUpdateTests` (gain/move/clear GPS, no duplicate rows, occurrence
  propagation, trigger presence); full 172-test suite green.
- Embargo on watch today: no GPS in bundle → Nearby shows explanatory empty
  state; Detail shows "Location hidden until gates open" instead of Navigate.

## Verification strategy
- Preview-driven: every screen has `#Preview`s (including loading/empty/restricted
  states) rendered via `mcp__xcode__RenderPreview` before simulator passes.
- `PlayaGeo` math under `swift test`; PlayaDB sync-merge under PlayaDBTests.
- Watch simulator flows get entries in `.claude/skills/drive-app/references/flows.md`
  as they land (per skill maintenance rule).
- Commit after each validated phase chunk (per CLAUDE.md source-control policy).

## Cross-references
- `Docs/2026-07-03-playadb-audit-and-improvements.md` — PlayaDB audit this branch
  builds on (region-narrowed observations, column-limited metadata writes — the
  sync merge must follow the same rules).
- `.claude/skills/drive-app/SKILL.md` — simulator driving + DB verification recipes.
