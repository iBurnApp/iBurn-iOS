# 2026-07-25 — Yap→PlayaDB default audit + remaining feature migration

**Branch:** `2026-updates`
**Related:** `2026-07-11-swiftui-lists-default-on.md`, `2026-07-07-architecture-analysis-and-roadmap.md`,
`2026-07-03-playadb-audit-and-improvements.md`

## High-Level Plan

Chris: *"audit the remaining migration we need to get off of yapdatabase for the 2026 release by
default. we can keep yapdb and legacy code around, but let's ensure all features use the new
playadb code via feature flag by default. then proceed to use Opus 5 subagents at high effort
level for implementation."*

Four parallel Explore agents audited (1) map pins/breadcrumbs, (2) Visit List + Audio Tour,
(3) misc default-path Yap consumers, (4) the network update pipeline. Findings consolidated
below; scope decisions confirmed with Chris; implementation runs as Opus subagents in two waves.

### Scope decisions (Chris, 2026-07-25)

1. **OTA updater (PlayaUpdateService): KEEP DEFERRED.** Consistent with the 07-11 decision —
   PlayaDB stays bundle-seeded for 2026; August drops reach PlayaDB via app updates.
2. **Audio Tour: add `audio_tour_url` column** to PlayaDB (migration v4) + PlayaAPI field,
   matching legacy semantics (remote URL OR local file).
3. **Map "Visible Pins" list: rebuild on PlayaDB** (it is silently broken/empty today).
4. **Calendar sync (EKEvent): migrate to PlayaDB-native NOW** (Chris chose this over keeping
   the Yap bridge), flag-gated with the Yap hook retained as fallback.

## Audit Findings (2026-07-25)

### Already fully PlayaDB — the 07-07 roadmap doc was stale on these

- **User map pins**: 100% PlayaDB (`user_map_pins`) since commit `99587a3` (2026-04-05). All
  six CRUD paths verified: display `FilteredMapDataSource.swift:30-38`, create (sidebar star
  `MainMapViewController.swift:238-250`, bike/home, deep link `BRCDeepLinkRouter.swift:172-181`),
  edit title/drag (`UserMapViewAdapter.swift:65-71,302-341`), delete (`:271-283`), UserGuidance.
  `BRCUserMapPoint` survives only as an in-memory MapLibre annotation adapter
  (`BRCUserMapPoint+PlayaDB.swift`).
- **Breadcrumbs/location history**: standalone GRDB `LocationHistory.sqlite`
  (`iBurn/Tracks/LocationStorage.swift`) — never Yap in the shipping path.
- **Deep links**: `BRCDeepLinkRouter` resolves via PlayaDB, pushes PlayaDB SwiftUI detail;
  the `import YapDatabase` is unused.
- **Embargo unlock**: UserDefaults-only in both directions (`EmbargoPasscodeViewModel.swift:93-101`,
  `BRCEmbargo.m:38-52`). No DB touched on unlock.
- Recently Viewed, Mutant Vehicles, AI Guide, Data Updates screen UI, Credits, watch app: PlayaDB.

### Remaining default-on Yap feature surfaces

1. **Visit List** (More → Visit List, unconditional `MoreViewController.swift:403-407`).
   Fully Yap: `allObjectsGroupedByVisitStatusViewName` grouped view (`BRCDatabaseManager.m:384-410`)
   + `refreshVisitStatusGroupedView` versionTag hack, Yap FTS search via `SearchDisplayManager`,
   Yap cells, `YapViewAnnotationDataSource` map button. PlayaDB already has:
   `object_metadata.visit_status` (+`visit_status_updated_at`), `setVisitStatus`/`fetchObjects(visitStatus:)`
   (`PlayaDBImpl.swift:1991-2059`), watch precedent (`FavoritesScreen.swift:196-207`), and the
   `FavoritesViewModel`/`RecentlyViewedViewModel` multi-type section patterns to copy. No
   reactive visit-status observation API (one-shot fetch; matches RecentlyViewed precedent).
2. **Audio Tour** (More → Audio Tour, unconditional `MoreViewController.swift:458-462`).
   `SortedViewController` over Yap filtered view `audioTourViewName` (filter
   `art.audioURL != nil`, `BRCDatabaseManager.m:411-429`). PlayaDB `ArtObject` has **no audio
   column**; SwiftUI rows already resolve audio from disk (`MediaAssetProviding.localAudioURL`),
   `BRCAudioPlayer` already has DB-agnostic `BRCAudioTourTrack` API (`BRCAudioPlayer.swift:13-33,154-180`).
   2026 data currently has 0 `audio_tour_url` and 0 `.m4a` (arrives late season; 2025 had 87).
   `BRCMediaDownloader`'s instance/download path is dead code — never instantiated; only its
   static path helpers are used. So audio arrives only via bundled MediaFiles today.
3. **Map "Visible Pins" list** (`MapPinListViewController` via `ListButtonHelper.swift:29-34`).
   Yap-based (`SortedViewController`) and **functionally broken**: collects only
   `DataObjectAnnotation`, but the default map emits `PlayaObjectAnnotation` + `BRCUserMapPoint`
   → always empty.
4. **Data Updates screen actions**: UI is PlayaDB, but "Check for Updates"/"Reset" drive the Yap
   importer and then `reimportPlayaDB()` **from the bundle** (`DataUpdatesView.swift:205-247,262-286`).
   Fine while OTA-for-PlayaDB is deferred; becomes a clobber-hazard when it lands.
5. **Boot**: Yap open + bundled preload + OTA-to-Yap always run (`BRCAppDelegate.m:87-107`) —
   intentionally kept (feeds the kill-switch stack). But `ColorCache.prefetchAllColors`
   (`BRCAppDelegate.m:106`) does duplicate Yap-side color work every launch alongside PlayaDB's
   `ColorPrefetcher` (`DependencyContainer.swift:109-113`).
6. **Calendar/EKEvent**: identity lives only in Yap metadata (`calendarEventIdentifier`),
   written by `BRCEventObject.m:224-311` via the `FavoriteSyncService` hook
   (`FavoriteSyncService.swift:236-241`) and legacy `DetailDataService.swift:29-42`. EKEvents
   are per-occurrence (legacy Yap splits events per-occurrence as `"<apiUID>-<n>"`), alarms
   −90/−10 min. → migrating per decision 4.

### Intentional bridges (keep for 2026)

`FavoriteSyncService` PlayaDB→Yap favorites mirror (+ occurrence fan-out), notes/visit
dual-writes, Yap boot import. These keep the kill-switch stack coherent.

### Latent bugs found (fixing in this pass)

- `BRCDataObjectTableViewCell.swift:25-47` — legacy cell heart syncs PlayaDB with the raw Yap
  uid; for events (`"<apiUID>-<n>"`) the PlayaDB write silently no-ops. Reachable **by default**
  today via Visit List / Audio Tour / MapPinList cells.
- `DetailViewModel.swift:577-584` `syncNotesToYapDB` — writes with raw PlayaDB uid into
  `BRCEventObject.yapCollection`; never matches per-occurrence Yap keys.
- **Embargo passcode unlock never refreshes PlayaDB observations**:
  `PlayaDBAnnotationDataSource.startObserving()` captures `embargoAllowed` once (`:57`); the six
  list hosting controllers snapshot it too; `MoreViewController.showUnlockView` only reloads its
  table → locations don't appear until relaunch.
- Pin de-dup identity: `MapViewAdapter.swift:69-72` keys `BRCMapPoint` by `yapKey`, which is a
  fresh random UUID per DB rebuild (`BRCYapDatabaseObject.m:19-26`) — can never match; stable id
  is `pinId`.
- `LocationStorage.setup()` never calls `start()` → breadcrumbs record only after visiting
  More → Location History once per launch; `TracksViewController.setupStorage()` builds a
  second `LocationStorage` on the same file instead of `.shared`.
- PlayaDB→Yap visit-status mirror doesn't call `refreshVisitStatusGroupedView` → legacy Visit
  List groups stale under kill-switch.
- Zero tests for `UserMapPin` (package or app).
- Stale docs/comments: roadmap §1.3/§4 rows for pins/breadcrumbs; `FilteredMapDataSource` header;
  `FavoritesFilterable.swift:13-14` claims Yap is favorites source of truth.

### Network pipeline facts (for the deferred OTA bridge, future reference)

- Server JSON is byte-identical in shape to bundled JSON; `importFromData` accepts it as-is;
  `needsImport(bundleUpdateData:)` works on any update.json `Data` (`PlayaDBImpl.swift:2299-2317`).
- `importFromData` is full-replace, single transaction, all-types-required (only `mvData`
  optional — and nil leaves stale MV rows); `object_metadata`/`thumbnail_colors`/`user_map_pins`
  survive by construction; orphaned metadata rows never GC'd; no metadata-survival regression test.
- Yap importer discards `mv.json` silently (`BRCUpdateInfo.m:82-98` has no `mv` type).
- Downloaded JSON is never persisted (in-memory only, `BRCDataImporter.m:489`); no hand-off surface.
- Watch is bundle-only by design (`WatchSeeder.swift:14-15`).

## Implementation Plan (Opus subagents)

**Wave 1 (parallel):**
- **D — PlayaDB package schema**: migration `v4-audio-tour` (`art_objects.audio_tour_url` +
  PlayaAPI `Art` field + import mapping + `ArtFilter` support) and `v5-calendar-entries`
  (per-occurrence EKEvent identifier storage + CRUD API) + package tests.
- **A — Visit List SwiftUI/PlayaDB**: `VisitListView`/VM/hosting controller (segmented
  All/Want to Visit/Visited, ⭐/✅ sections, multi-type rows, map button, paging detail),
  `MoreViewController` branch on `useSwiftUILists`, tests.
- **B — Map pin list rebuild + map Yap cleanups**: PlayaDB-native visible-annotations list for
  the main map; keep legacy class for legacy `MapListViewController` contexts; delete dead Yap
  connections/imports (`MainMapViewController.swift:21-22,49-50`, `MapViewAdapter`,
  `BRCDeepLinkRouter`); fix pin de-dup identity; `UserMapPin` package tests.
- **C — Cross-cutting fixes**: cell/notes uid bugs, embargo-unlock live refresh, ColorCache
  prefetch gating on `useSwiftUILists`, LocationStorage start/shared fixes, visit-mirror
  regroup call, doc/comment corrections.

**Wave 2 (parallel, after D lands):**
- **E — Audio Tour SwiftUI/PlayaDB screen**: art-with-audio list (URL or local file), per-row
  play, Play All + intro track + SoundCloud via `BRCAudioTourTrack`/`AudioPlayerProtocol`,
  `MoreViewController` branch on `useSwiftUILists`, tests.
- **F — PlayaDB-native calendar sync**: `EventCalendarService` (protocol+Impl+factory,
  EventKit protocolized for tests), per-occurrence EKEvents with −90/−10 alarms, identifiers in
  PlayaDB (v5 API), new flag `Preferences.FeatureFlags.usePlayaDBCalendarSync` default **true**;
  when true, `FavoriteSyncService` calendar hook + `DetailDataService` legacy path route through
  the new service (single owner across stacks); when false, legacy Yap hook. Tests.

**Integration (main session):** resolve overlaps, full build + `iBurnTests` + PlayaDB package
tests, sim sanity pass (drive-app flows), flows.md updates, commit(s).

## Expected Outcomes

- All More-tab features (Visit List, Audio Tour) + the map's list button run SwiftUI/PlayaDB by
  default, flag-fallback to legacy.
- Calendar EKEvents owned by a PlayaDB-native service by default (flagged).
- Default-path Yap writes reduced to: boot import (intentional), favorites/notes/visit mirrors
  (intentional bridges).
- Bug fixes above landed with tests.
- Explicitly out of scope: OTA→PlayaDB updater (deferred), watch data updates, Yap deletion
  (post-season, roadmap §4).

## Wave 1 — B outcome (map pin list + map Yap cleanups)

**New PlayaDB-native "Visible Pins" screen** (`iBurn/ListView/VisiblePins{ViewModel,View,HostingController}.swift`):
sections Art / Camps / Events / Map Pins, nearest-first when a location is available
(alphabetical otherwise), `ObjectRowView` rows for data objects and a compact marker-image
row for `BRCUserMapPoint`s. Rows de-dupe by stable id (art/camp uid, event uid, pin `pinId`).

- **No database round trip.** `PlayaObjectAnnotation` now carries the object it was built
  from (`PlayaAnnotationObject` enum: art / camp / eventOccurrence / event). The list renders
  straight off the annotations already on the map, so an event row shows the exact occurrence
  that placed the pin instead of re-resolving one.
- **List-button split** lives in `ListButtonHelper.listButtonPressed`: if any annotation inside
  the visible bounds is a `DataObjectAnnotation` (legacy Yap-fed maps behind the
  `useSwiftUILists` kill-switch), push the old `MapPinListViewController`; otherwise push
  `VisiblePinsHostingController`. Covers both attach sites (`MainMapViewController`'s
  `FilteredMapDataSource` and `MapListViewController`'s `StaticAnnotationDataSource`).
  `MapPinListViewController` is kept, not deleted.
- **Data source**: the screen reads `mapView.annotations` (what `MapViewAdapter` actually put
  on the map from `FilteredMapDataSource`) filtered to `visibleCoordinateBounds`, so no new
  accessor on `FilteredMapDataSource` was needed and the same code works for every map.
- **Pin tap**: pops back to the map, recenters (unanimated, so the pin is inside the viewport)
  and selects the annotation, opening its callout. Data-object rows push the PlayaDB SwiftUI
  detail via `DetailViewControllerFactory.create(with:playaDB:)`.
- **Pin de-dup identity fixed**: `MapViewAdapter.keyForAnnotation` now keys `BRCUserMapPoint`
  by `pinId` (stable PlayaDB row id) instead of the per-instance random `yapKey`.
- **Dead Yap removed**: `MainMapViewController.uiConnection`/`writeConnection` + its
  `import YapDatabase`; `MapViewAdapter`'s `import YapDatabase` and duplicate `import PlayaDB`;
  `BRCDeepLinkRouter`'s `import YapDatabase`.
- **Tests**: `Packages/PlayaDB/Tests/PlayaDBTests/UserMapPinTests.swift` (10 tests: save/fetch
  round trip incl. nil title, upsert-replace on same id, delete + unknown-id no-op,
  `created_date` ordering, observation on insert/update/delete) and
  `iBurnTests/VisiblePinsViewModelTests.swift` (sectioning, de-dup, payload-less annotations
  ignored, distance vs. alphabetical ordering, untitled-pin naming).
- `flows.md` §6 (Map + embargo) updated to describe the new list screen and the split.

## Wave 1 — C outcome (cross-cutting fixes)

Seven fixes from "Latent bugs found". No `project.pbxproj` changes (`iBurn/` and `iBurnTests/`
are `PBXFileSystemSynchronizedRootGroup`s, so new files are picked up automatically).

1. **Legacy cell heart dropped the PlayaDB write for events** —
   `BRCDataObjectTableViewCell.swift`. New testable helper
   `BRCDataObjectTableViewCell.playaDBUID(for:)` normalizes event uids via
   `FavoriteSyncServiceImpl.apiEventUID(fromYapUID:)` (art/camp pass through untouched, even
   when they end in `-<digits>`). Yap-write-first ordering preserved.
2. **Notes mirror used the wrong event uid** — new
   `FavoriteSyncService.mirrorNotes(type:uid:notes:)` (protocol + Impl) reuses the occurrence
   fan-out machinery, *without* the calendar hook, and skips equal-value writes.
   `DetailViewModel.syncNotesToYapDB(uid:yapCollection:notes:)` became
   `syncNotesToYapDB(type:uid:notes:)` and routes through the service (4 call sites). The
   duplicated `"<apiUID>-<digits>"` key matching in the Impl was factored into
   `FavoriteSyncServiceImpl.occurrenceKeys(from:apiUID:)` — a `[String] -> [String]` helper, so
   no YapDatabase type enters a member signature (the swiftmodule/@testable gotcha).
3. **Embargo unlock now refreshes live PlayaDB UI** — no notification existed, so
   `iBurn/EmbargoNotification.swift` (new) adds `Notification.Name.BRCEmbargoDidClear` plus an
   `@objc(BRCEmbargoNotifier)` shim with `+postDidClear` (Notification.Name extensions are
   invisible to ObjC) that hops to the main thread. Posted from
   `EmbargoPasscodeViewModel.unlockButtonPressed` and from
   `BRCAppDelegate.enteredBurningManRegion` — the latter also snapshots the flag *before*
   calling `+allowEmbargoedData`, which itself flips the flag once the festival starts (that
   early-return made the existing region-unlock branch effectively dead).
   Observers: `PlayaDBAnnotationDataSource` restarts its observations (new `isObserving` gate so
   a stopped data source never resurrects) and each of the six list hosting controllers rebuilds
   its SwiftUI root view via an extracted `makeRootView()`. `MoreViewController.showUnlockView`
   needed no change (it already dismisses + reloads; the SwiftUI unlock view auto-dismisses
   0.5s after `isDataUnlocked` flips).
4. **Duplicate color prefetch** — `BRCAppDelegate.m` now gates `[ColorCache.shared
   prefetchAllColors]` behind `!BRCPreferenceService.useSwiftUILists`. The flag is exposed to
   ObjC as a new `@objc public static var useSwiftUILists` on the existing `BRCPreferenceService`
   bridge (`Preferences/PreferenceServiceFactory.swift`). PlayaDB's `ColorPrefetcher` serves the
   default stack.
5. **Breadcrumbs recorded only after visiting Tracks** — `LocationStorage.setup()` now calls
   `start()` (which still honors `UserDefaults.isLocationHistoryDisabled`) and is idempotent;
   `TracksViewController.setupStorage()` reuses `LocationStorage.shared` instead of opening a
   second `DatabaseQueue` + `CLLocationManager` on the same file.
6. **Legacy Visit List grouping staleness** — the visit-status mirror now fires a
   `FavoriteSyncVisitStatusDidChangeHook` post-commit, wired in
   `FavoriteSyncServiceFactory.shared` to
   `BRCDatabaseManager.refreshVisitStatusGroupedView(completionBlock: nil)` (matching
   `DetailDataService.updateVisitStatus`). Injected rather than called directly so tests stay
   off the shared `BRCDatabaseManager`; the private mirrors now return `didWrite` so the hook
   only fires on a real change.
7. **Stale docs/comments** — `2026-07-07-architecture-analysis-and-roadmap.md` got
   "**Correction 2026-07-25:**" notes on §1.3's pins/breadcrumbs row, §1.4's map bullet, the
   Phase 2 migration bullet and risk 5 (history left intact); `FilteredMapDataSource` header and
   `FavoritesFilterable.swift`'s "Yap is the favorites source of truth" claim corrected.

**Tests** — `iBurnTests/YapPlayaDBBridgeTests.swift` (new, temp Yap DB via
`BRCTestDatabaseHelper` + in-memory PlayaDB, `XCTUnwrap` only): cell uid normalization (incl. an
end-to-end `fetchEvent` miss/hit against a real PlayaDB), notes fan-out to all occurrences +
non-matching-neighbor isolation + clear-with-empty-string + equal-value skip (asserted via
`connection.snapshot`) + unknown-uid/MV no-ops, the visit-status regroup hook firing exactly
once per real change and never on no-op mirrors, and the embargo notification name/post.
`StubFavoriteSyncService` in `VisitListViewModelTests.swift` (Wave 1 — A's file) needed a
one-line `mirrorNotes` stub for the protocol addition.

**Verification** — `xcodebuild build -scheme iBurn` (iPhone 17 Pro Max, iOS 26.2, arm64):
**BUILD SUCCEEDED**. `xcodebuild test -scheme iBurnTests -only-testing:iBurnTests/YapPlayaDBBridgeTests
-only-testing:iBurnTests/FavoriteSyncServiceTests`: **28 tests, 0 failures** (11 new + 17 existing).
`DetailViewModelTests` + `DetailServicesTests` (the notes-path consumers): **26 tests, 0 failures**.
`project.pbxproj` unchanged (no `DEVELOPMENT_TEAM` churn). Note: the build used the default
DerivedData location rather than a scratch `-derivedDataPath` — the machine was briefly out of
disk space from four concurrent agent builds, and reusing the existing incremental tree avoided a
second 4 GB copy.

---

## Wave 1 — A outcome (Visit List → SwiftUI/PlayaDB)

New `iBurn/ListView/VisitListViewModel.swift` / `VisitListView.swift` /
`VisitListHostingController.swift`; `MoreViewController.pushVisitListView()` branches on
`useSwiftUILists` (legacy `VisitListViewController` retained as kill-switch). One-shot
`fetchObjects(visitStatus:)` for `.wantToVisit` + `.visited` (no reactive visit-status
observation exists — same pattern as Recently Viewed), refreshed on `viewWillAppear` **and**
`UIApplication.didBecomeActiveNotification`. Segmented All / Want to Visit / Visited, sections
"⭐ Want to Visit" / "✅ Visited" (never an unvisited section, matching legacy), in-memory search
(matching Favorites/RecentlyViewed), hearts through the `*DataProvider`s so the Yap mirror fires,
map button + paged detail per the RecentlyViewed pattern. No visit-status mutation from the list
(legacy parity — the detail screen owns that write and its Yap mirror). Tests:
`iBurnTests/VisitListViewModelTests.swift` (13).

Follow-up noted, not fixed: on iOS there is no notification when watch favorites/visit status
arrive (`.favoritesSyncDidApply` is watch-only; the phone applies them in `DependencyContainer`'s
`onApplied` closure). Favorites lists get it free via GRDB observation; the Visit List would need
a post from that closure for live in-foreground updates. Also observed: `RecentlyViewedViewModel`
keys event hearts by occurrence uid rather than parent uid, so its event hearts never light up
(pre-existing, untouched).

## Wave 2 — E outcome (Audio Tour → SwiftUI/PlayaDB)

New `iBurn/ListView/AudioTourViewModel.swift` / `AudioTourView.swift` /
`AudioTourHostingController.swift`; `MoreViewController.showAudioTour()` branches on
`useSwiftUILists` (legacy `AudioTourViewController` retained). Membership is the union the legacy
screen implied (`art.audioURL = localAudioURL ?? remoteAudioURL`): art with `audio_tour_url` in
PlayaDB (v4 column, filtered at SQL via `ArtFilter(hasAudioTour: true)`) **plus** art with a local
`MediaFiles/<uid>.m4a`. Local uids come from a single directory listing behind the
`AudioTourAssetProviding` protocol (stubbable in tests); when no local recordings exist the
observation uses the SQL filter, otherwise it observes unfiltered and applies the union in memory.
Track URLs prefer the local file over the remote URL. Toolbar: Play All, intro track (only when
`MediaFiles/intro.m4a` exists), SoundCloud. Playback goes through the DB-agnostic
`BRCAudioTourTrack` / `BRCAudioPlayer` API. Tests: `iBurnTests/AudioTourViewModelTests.swift`.

## Wave 2 — F outcome (PlayaDB-native calendar sync)

New `iBurn/Calendar/EventCalendarService.swift` (actor `EventCalendarServiceImpl`, coalescing
concurrent reconciles), `EventStoreProviding.swift` (EventKit behind a protocol so tests inject a
spy), `LegacyCalendarIdentifierStore.swift` (Yap takeover). New flag
`Preferences.FeatureFlags.usePlayaDBCalendarSync` (default **true**).

**Single owner per flag state.** `EventCalendarHookRouter.makeCalendarRefreshHook` wraps the
existing `FavoriteSyncCalendarRefreshHook` rather than changing the `FavoriteSyncService`
protocol: flag on → normalize the Yap uid to its API uid and hand off to `EventCalendarService`
(EKEvents owned by it, identifiers in PlayaDB `event_calendar_entries`); flag off → the original
Yap `refreshCalendarEntry` path, untouched. `DetailDataService` gained an optional
`calendarService` and skips its in-transaction `refreshCalendarEntry` when the service owns the
entry, reconciling post-commit instead. `EventCalendarServiceFactory.shared` resolves to
`DependencyContainer.eventCalendarService`, so hook and detail path share one actor instance.
Watch-sync favorites inherit the new path for free (they already funnel through
`FavoriteSyncService`). Legacy alarm offsets preserved (−90 min, −10 min). Takeover: when
reconciling an event with no PlayaDB entries, legacy identifiers are read from Yap metadata,
their EKEvents removed and the Yap identifiers cleared, so upgrading users don't get orphaned
calendar entries. Tests: `iBurnTests/EventCalendarServiceTests.swift`.

## Integration & Verification (main session, 2026-07-25)

Both Wave 2 agents were terminated mid-run by a session usage limit **after** writing their
implementation and test files but **before** self-verifying; the integration pass below is
therefore the first verification those two workstreams received.

- **App build**: `xcodebuild -scheme iBurn` (iPhone 17 Pro Max, **iOS 26.5** — 26.2 runtimes are
  gone from this machine): **0 errors, 0 warnings**.
- **`iBurnTests`**: **202 passed, 0 failures**. All six new/touched suites confirmed executed and
  passing: `VisitListViewModelTests`, `VisiblePinsViewModelTests`, `AudioTourViewModelTests`,
  `EventCalendarServiceTests`, `YapPlayaDBBridgeTests`, `FavoriteSyncServiceTests`.
- **Packages**: PlayaDB **238 passed**, PlayaAPI **71 passed**.
- **Two Swift-6-fatal warnings fixed in new test code** (both would be hard errors under Swift 6):
  `EventCalendarServiceTests.swift` held an `NSLock` across an async boundary (extracted a
  synchronous `recordEnsureAccess()`); `YapPlayaDBBridgeTests.swift` called the MainActor-isolated
  `playaDBUID(for:)` from a non-isolated async test (annotated the test `@MainActor`). Test suite
  now compiles warning-free.
- **`project.pbxproj` unchanged** — no `DEVELOPMENT_TEAM` churn to revert.

### Simulator pass (iPhone 17 Pro Max, iOS 26.5, existing install — upgrade path)

- **Migrations applied in place** on a pre-existing v1–v3 database:
  `v1-initial-schema, v2-favorite-sync, v3-visit-status, v4-audio-tour, v5-calendar-entries`.
- **Map → Visible Pins** (rebuilt screen): correct empty state with no pins in view; after
  dropping a Home pin at "2:40 & Eternal" the pin appears in a Map Pins row with walk/bike times.
  This screen was silently always-empty before this change.
- **More → Visit List**: renders "⭐ Want to Visit" (Snuggles, favorited) and "✅ Visited"
  (Best Butt) with thumbnails and embargo-correct "? min" distances; segments, search field and
  map button all present.
- **More → Audio Tour**: correct empty state ("Audio tour content arrives later in the season…").
  Verified this is *correct*, not a failure: the 2026 payload has **0** `audio_tour_url` values,
  and the 87 `.m4a` files left on this simulator from the 2025 bundle carry 2025 art uids —
  `SELECT COUNT(*) FROM art_objects WHERE uid IN (<local uids>)` returns **0**. The intro button
  correctly appears because `MediaFiles/intro.m4a` genuinely exists on this device.
- **Calendar sync round trip** (the riskiest item, flag default on): favoriting "Welcome Jam
  Lounge" wrote `event_calendar_entries` = `(TRMHhqiTnH7viCZ9f2Le, 2026-08-31T01:00:00Z,
  A0397B35-…:8E1F3577-…)` — a real EventKit identifier, and the occurrence key is Sun Aug 30
  6:00 pm PDT expressed in UTC, i.e. correct. Unfavoriting removed both the EKEvent and the row
  (`COUNT(*) = 0`, `is_favorite = 0`). A previously-favorited event from an earlier session
  (`pZKm9hfsiDbnz8QXueVW`) has no PlayaDB entry, as expected — its legacy Yap-bookkept entry is
  taken over on its next reconcile.

### Deliberately still on Yap after this pass

Boot-time Yap open + bundled preload + OTA-to-Yap (feeds the kill-switch stack); the
favorites/notes/visit-status Yap mirrors (intentional bridges); the legacy list/detail VCs behind
their flags. **OTA→PlayaDB updater remains deferred per decision 1** — PlayaDB is bundle-seeded
for 2026, so August data drops reach the shipping UI only through app updates.
