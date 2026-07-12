# 2026-07-12 — Watch browse for all data types + visit status ("want to visit")

**Branch:** `2026-updates`
**Related:** `2026-07-11-swiftui-lists-default-on.md` Session 2 (favorites sync this builds
on), `2026-07-03-watchos-mvp-plan.md` (all MVP phases complete as of yesterday).

Chris: *"I couldn't find a way to browse all data types on the watch. Camp, art, event,
mutant vehicle. Then favorites/want-to-visit etc for the data types. We'll also need to
handle data update mechanism. I think for now we can just bundle databases with each app
but for incremental updates not sure what to do."*

## High-Level Plan

1. **pbxproj unblocking (done first, by hand):** converted the `iBurnWatch` group to a
   `PBXFileSystemSynchronizedRootGroup` (same UUID `73700CCA…`, so the main-group child
   reference is untouched): removed the 8 explicit file refs + build-file entries and the
   per-file Sources/Resources lines, added `fileSystemSynchronizedGroups` to the target.
   New Swift files in `iBurnWatch/` now join the target automatically — no more manual
   project surgery (which blocked past sessions; see 2026-07-06 doc). The in-place
   "iBurnWatch CityGeo" geojson refs (Submodules) are intentionally untouched.
   `BlackRockCity.gpx` now ships in the watch bundle as a side effect (1 KB, harmless).
   Verified: watch + iOS builds, Assets.car + geojson still in the bundle.
2. **Watch browse (new screens, Fable agent):** map root's top-left toolbar button
   becomes **Browse** → list: Nearby / Camps / Art / Events / Vehicles.
   - Camps/Art/Vehicles: alphabetical `ObjectListScreen` with `.searchable`, distance
     when available, → existing `DetailScreen`.
   - Events: `EventListScreen` with a festival-day picker driven by
     `observeEventsByDayThenHour` (day keys come from the data — `YearSettings` is not in
     the watch target). **Adult gating replicated** (App Store content risk): `adlt`
     events excluded unless the user's location is on-playa
     (`PlayaMapData.pointOnPlaya != nil`), mirroring the phone's
     `EventFilter.excludingAdultEvents()`.
3. **Visit status → PlayaDB + sync (Fable agents):**
   - Migration `v3-visit-status`: `object_metadata.visit_status` (INT, default 0,
     `BRCVisitStatus` raw values: 0 unvisited / 1 visited / 2 wantToVisit) +
     `visit_status_updated_at` (LWW stamp, same reasoning as `favorite_updated_at`).
   - PlayaDB API: `VisitStatus` enum, `setVisitStatus(_:for:)`,
     `fetchObjects(visitStatus:)`.
   - `FavoriteSyncItem` reshaped (nothing shipped, no wire compat needed):
     `favoriteUpdatedAt: Date?` (was `updatedAt`), `visitStatus: Int`,
     `visitStatusUpdatedAt: Date?`. Snapshot = rows with either stamp non-NULL.
     `applyFavoriteSync` does **per-field LWW** (favorite and visit status merge
     independently; same-state skip per field, write only changed columns).
   - Phone: `DetailViewModel.updateVisitStatus` + `DetailDataService` dual-write to
     PlayaDB (event uid suffix normalization); incoming sync mirrors visit status into
     Yap via a new `FavoriteSyncService.mirrorVisitStatus` (fan-out for events, no
     calendar side effects).
   - Watch: `DetailScreen` gains a visit-status control; `FavoritesScreen` gains a
     filter menu — Show: Favorites / Want to Visit / Visited, Type: All / Camps / Art /
     Events / Vehicles.
4. **Data updates: recommendation only** (Chris is explicitly undecided; see below).

## Data update mechanism — assessment (no code this session)

Current state of record: both apps are bundle-seeded; `needsImport(bundleUpdateData:)`
already reseeds either app when a shipped bundle is newer than what was imported
(2026-07-04 fix). So "bundle databases with each app" is already how it works — every
App Store/TestFlight release refreshes both DBs, preserving `object_metadata`.

For incremental (OTA) updates, the legacy phone pipeline is already "incremental" at
file granularity: `update.json` carries per-type timestamps and the importer downloads
only changed type files (art/camp/event JSON), never per-row deltas. Recommendation for
PlayaDB (roadmap Phase 1, post-season unless the embargo drop forces it):

- Build one shared `PlayaUpdater` in the PlayaDB/PlayaAPI package: fetch `update.json`
  from `UPDATES_URL`, compare per-type timestamps against `getUpdateInfo()` (the
  comparison logic already exists as `needsImport`), download changed files, call
  `importFromData` (idempotent upsert; spatial/FTS triggers keep indexes consistent;
  favorites/visit metadata is a separate table and survives).
- Phone and watch each run it over their own URLSession (the watch is standalone-capable
  with WiFi; no phone-relay needed). A phone→watch `transferFile` relay is a power
  optimization to consider later, not a prerequisite.
- The embargo unlock then "just works": the post-gates data drop is a normal update
  whose camp/art rows carry GPS; `*_spatial_update` triggers (built 2026-07-03 for
  exactly this) keep region queries correct.
- This season, if no updater ships: data refreshes (including the location drop) reach
  users via app updates, same as the plan of record from yesterday's session.

## Results

All shipped. Executed with 4 Fable subagents (PlayaDB visit-status core / watch browse
screens / phone integration / watch visit UI); pbxproj conversion, a parity-gap fix, and
E2E verification done in the main session.

### What shipped

1. **pbxproj:** `iBurnWatch` is now a `PBXFileSystemSynchronizedRootGroup` (32 explicit
   file-ref/build-file lines deleted; target gained `fileSystemSynchronizedGroups`).
   Both apps verified building with Assets.car + geojson intact.
2. **Watch browse** (new files: `BrowseScreen.swift`, `ObjectListScreen.swift`,
   `EventListScreen.swift`; map top-left toolbar → Browse):
   Nearby / Camps / Art / Vehicles / Events. Generic alphabetical `.searchable` lists →
   existing DetailScreen; Events uses one `observeEventsByDayThenHour` subscription with
   day chips (defaults to today, in-memory day switching) and replicates the phone's
   adult gating (all `EventType` codes minus `adlt` unless `pointOnPlaya` says on-playa).
3. **PlayaDB `v3-visit-status`:** `visit_status` (0/1/2 = BRCVisitStatus raw) +
   `visit_status_updated_at`; `VisitStatus` enum; `setVisitStatus(_:for:)` (no-op on
   same value), `fetchObjects(visitStatus:)`. `FavoriteSyncItem` reshaped
   (`favoriteUpdatedAt: Date?`, `visitStatus: Int`, `visitStatusUpdatedAt: Date?`) and
   `applyFavoriteSync` upgraded to **per-field LWW** (fields merge independently;
   same-state per-field skip keeps the no-write loop-prevention property). Package
   suite 206/206 (17 new merge tests).
4. **Phone:** `FavoriteSyncService.mirrorVisitStatus` (event fan-out, read-compare
   skip, no calendar); `DependencyContainer.onApplied` mirrors both fields;
   `DetailDataService.updateVisitStatus` dual-writes PlayaDB (event uid suffix
   normalized via `apiEventUID`). 5 new mirror tests (17 total in
   FavoriteSyncServiceTests; also fixed a latent test-fixture bug — helpers now store
   `BRCCampMetadata` etc., since `metadataWithTransaction` type-checks the subclass).
5. **Parity gap found during E2E and fixed (main session):** the PlayaDB-backed detail
   (`generatePlayaFooterCells`) had **no VISIT STATUS cell** and
   `DetailViewModel.updateVisitStatus` silently no-oped for non-legacy subjects — so
   want-to-visit was unreachable in the shipping default stack. Fixed: cell added after
   USER NOTES, `playaVisitStatus` loaded in all metadata paths (incl. preloaded), and
   `updateVisitStatus` now handles all subject cases (PlayaDB write + Yap mirror;
   occurrence uses `occ.event.uid`).
6. **Watch visit UI:** DetailScreen visit-status button → sheet (SwiftUI `Menu` is
   `@available(watchOS, unavailable)`); FavoritesScreen filter sheet — Show:
   Favorites/Want to Visit/Visited, Type: All/Camps/Art/Events/Vehicles; per-mode
   empty states; title tracks mode.

### Verification

- PlayaDB 206/206; iBurnTests full suite green (re-run after the DetailViewModel fix);
  all builds 0 warnings; no stray pbxproj churn beyond the intended conversion.
- Paired-sim E2E: fresh watch install ran v1→v3 migrations, pulled phone favorites on
  activation (reshaped payload). Watch: Browse menu, Camps list, Events day chips
  (Sun 30 ⇄ Tue 1 verified), detail sheet set Snuggles → Want to Visit → phone PlayaDB
  `visit_status=2` + Yap blob decoded `[2, True]`; Favorites filter "Want to Visit"
  showed only Snuggles. Phone: VISIT STATUS cell on the PlayaDB camp detail set
  Best Butt → Visited → watch row `camp|Best Butt|0|1` inserted via sync + phone Yap
  blob `[1, False]`.
- flows.md watch section updated (Browse flow, visit-status sync checks, rating-prompt
  and watch-keyboard automation quirks).

### Known gaps / follow-ups

- Watch list search verified in code only (the watch keyboard's AX field rejects
  `type_text`; manual check recommended on device).
- Legacy Visit List screen (`VisitListViewController`, More tab) still reads Yap only —
  fine, since the mirrors keep Yap in sync from every write path.
- Data updater (`PlayaUpdater`) not built — see assessment above; recommend first
  post-season item unless the embargo drop should go OTA this year.
