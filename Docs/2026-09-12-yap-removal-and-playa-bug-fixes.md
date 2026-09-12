# 2026-09-12 — Finish YapDatabase removal + post-playa bug fixes

## High-Level Plan

The 2026 event is over. Two tracks, run by the main session as orchestrator with
Sonnet explore agents and Opus implement/validate agents:

### Track A — Playa bug list (user's 2026 complaints)

| # | Complaint | Root cause (explored) | Fix owner |
|---|-----------|------------------------|-----------|
| 1 | Map pin callout shows "Hosted by Camp" instead of camp name + address | `EventObject.primaryLocationString` returns a literal placeholder; the zoomed-in region path (`MapRegionAnnotationFilter.annotations`) builds pins from bare `EventObject`s via `PlayaObjectAnnotation(event: EventObject)` even though `refreshRegionAnnotations()` already fetched joined `EventObjectOccurrence`s and only kept their UIDs | Opus "map pins" agent |
| 2 | Events happening now still appear at zoom with the map Events filter off | Only `PlayaDBAnnotationDataSource.startObserving()` reads `UserSettings.showActiveEventsOnMap`; the region path's event branch is unconditional and `MainMapViewController` re-runs it on filter Done | same agent |
| 3 | Expired events stay on the map; needs a refresh interval | `refreshRegionAnnotations()` only runs on regionDidChange / embargo clear / filter Done; `activeEventUIDs` is frozen until the next pan; no timer, no foreground/significant-time hooks | same agent (scheduler modeled on `EmbargoUnlockScheduler`) |
| 4 | Detail mini-map doesn't show you and the pin | `DetailMapViewRepresentable.updateUIView` creates a new `MapViewAdapter` per update, whose init sets `mapView.delegate = self`, stealing it from the Coordinator; `mapViewDidFinishLoadingMap` never fires so `brc_showDestination` never runs | Opus "mini-map" agent |

### Track B — Finish migrating off YapDatabase

Inventory (Sonnet audit, verified against code; the 2026-07-25 audit doc is accurate for its scope):

- **Boot/import stack:** `BRCAppDelegate.m` (Yap open, `preloadExistingData`, `loadUpdatesFromURL:`), `BRCDataImporter.{h,m,swift,_Private.h}`, `BRCDatabaseManager.{h,m,swift}`, Mantle model family (`BRCDataObject`, `BRCYapDatabaseObject`, `BRCEventObject`, `BRCRecurringEventObject`, `BRCObjectMetadata`, `BRCUpdateInfo`, `BRCMapPoint`, `BRCArtImage`, `BRCCampImage`, `BRCCreditsInfo`, `BRCEventTime`, `BRCImageColors`, `BRCVisitStatus.swift`, `BRCDataObject+Relationships`, `BRCDataObject+Events.swift`).
- **Bridges:** `FavoriteSyncService.swift`, `DetailDataService.swift` (Yap→PlayaDB sync + `apiEventUID(fromYapUID:)`), `DetailViewModel.syncNotesToYapDB`, `BRCDataObjectTableViewCell.swift`, `Calendar/LegacyCalendarIdentifierStore.swift`, `EventCalendarHookRouter` in `EventCalendarService.swift`.
- **Kill-switch legacy UI** behind `Preferences.FeatureFlags.useSwiftUILists` / `usePlayaDBCalendarSync` (both default true): `FavoritesViewController`, `ArtListViewController`, `EventListViewController`, `NearbyViewController`, `VisitListViewController`, `AudioTourViewController`, `MapPinListViewController`, `SortedViewController`, `HostedEventsViewController`, plus plumbing `YapViewHandler`, `YapTableViewAdapter`, `YapDatabaseConnection+iBurn`, `YapDatabaseViewConnection+iBurn`, `AnnotationDataSource.swift` (Yap classes), `SearchDisplayManager`, `BRCDataSorter`, `BRCMediaDownloader` (dead). Read sites: `BRCAppDelegate+Dependencies.swift`, `MoreViewController.swift`, `ListButtonHelper.swift`, `FeatureFlagsView.swift`.
- **Pods:** `YapDatabase` (submodule path pod) and `Mantle` are Yap-only; `CocoaLumberjack` is used broadly and stays. No direct pbxproj references (synced groups + Pods xcconfig).
- **Seed:** `iBurn/iBurn-2026.zip` (Yap seed) — auto-included via synced group; consumer path via `Bundle.brc_dataBundle`.
- **Tests on Yap:** `BRCDataImportTests`, `BRCDataSorterTests`, `BRCTestDatabaseHelper`, `YapPlayaDBBridgeTests`, `FavoriteSyncServiceTests`, Yap parts of `EventCalendarServiceTests`.
- **Watch, deep links, notifications, MainMapViewController, MapViewAdapter:** already Yap-free.

**Decision — no bulk Yap→PlayaDB user-data migration.** None ever existed; the bridges only mirror new writes. But the shipped 2026 release already ran every visible surface on PlayaDB, so any Yap-only favorites/notes have been invisible all season. Deleting Yap therefore loses nothing users can currently see. (User can override; a direct-SQLite reader of Yap's `database2` table decoding `BRCObjectMetadata` keyed archives would be the route if wanted.)

**Prerequisite — OTA→PlayaDB updater.** Today the only OTA path writes into Yap and `DataUpdatesView` re-imports PlayaDB from the *bundle*. An Opus agent is building `DataUpdateService` (protocol + Impl + factory) that downloads `update.json` + per-type JSON, persists to Application Support, and calls `PlayaDB.importFromData`, then rewires app launch and `DataUpdatesView`.

**Phases:**
1. OTA→PlayaDB updater (in progress, parallel with Track A).
2. Delete legacy UI + flags + bridges + Yap plumbing.
3. Delete boot/import stack + Mantle models + Yap seed zip + Yap tests.
4. Podfile: drop `YapDatabase` and `Mantle`; `pod install`; remove `Submodules/YapDatabase`.
5. Validation agent: full build, `iBurnTests`, PlayaDB package tests, drive-app pass on all four bugs.

## Technical Details

_(filled in as agents report)_

## Context Preservation

- Screenshots from playa: callout "Foosball & Trampoline Takeover / Hosted by Camp"; detail view "Tea House Night Lounge" mini-map at city-wide zoom without pin/user; map at 4:56 & Fulcrum showing event pins.
- Backlog memory (2026-08-28) already listed "retire Yap boot import", "stop shipping -shm in Yap seed" — both subsumed by full removal.

## Cross-References

- `Docs/2026-07-25-playadb-default-yap-audit-and-migration.md`
- `Docs/2026-07-26-playa-seed-cli.md`
- `Docs/2026-08-08-map-config-tabs-search-scope.md`
- `Docs/2026-08-28-maplibre-voiceover-crash-and-boundary-passcode.md`

## Expected Outcomes

- Event callouts read "Camp Name · address · time"; Events filter off hides all event pins at every zoom; event pins drop off within a minute of ending and on foreground; detail mini-map frames user + pin.
- No `YapDatabase`/`Mantle` in Podfile, no `Yap` symbols in the app, OTA updates land in PlayaDB.

---

## Detail mini map never framed its pin (SwiftUI)

### Problem
`DetailView`'s embedded map preview (`DetailView.swift:236-249` → `DetailMapViewRepresentable`)
always showed the whole city at zoom 13. The object's pin and the user's blue dot were never
framed, unlike the legacy `BRCDetailViewController` which called
`-[MLNMapView brc_showDestination:animated:padding:]` in `viewDidAppear`.

### Root cause
`DetailMapViewRepresentable.updateUIView` built a **brand-new `MapViewAdapter` on every SwiftUI
update**, and `MapViewAdapter.init` does `self.mapView.delegate = self` — stealing the delegate
from `context.coordinator`. `MapViewAdapter` implements `mapView(_:didFinishLoading style:)` but
not `mapViewDidFinishLoadingMap(_:)`, so the coordinator's `mapViewDidFinishLoadingMap` never
fired, `isMapLoaded` stayed `false`, and the pending `brc_showDestination` never ran.

### Fix
`iBurn/Detail/Views/DetailMapViewRepresentable.swift` rewritten:

* `Coordinator.attach(to:)` builds the `MapViewAdapter` **once** in `makeUIView`, then takes the
  delegate back (`mapView.delegate = self`) and forwards the eight delegate methods the adapter
  implements (`didFinishLoading style:`, `viewFor:`, `annotationCanShowCallout:`, `didDeselect:`,
  left/right callout accessory, `calloutAccessoryControlTapped:`, `regionDidChangeAnimated:`).
* `updateUIView` now only calls `Coordinator.update(annotation:)`, which swaps the adapter's
  `dataSource` + `reloadAnnotations()` when the pin actually changed. Change detection is by
  coordinate + title (`DetailMapFramingState.isEquivalent`) because the `dataObject` initializer
  mints a fresh `DataObjectAnnotation` on every SwiftUI pass.
* The framed annotation is read back through `StaticAnnotationDataSource.allAnnotations()` so an
  embargo-filtered pin is treated as "no location" rather than framed and never drawn.
* Framing triggers: `mapViewDidFinishLoadingMap`, `mapViewDidFinishRenderingFrame(_:fullyRendered:)`
  (safety net — SwiftUI can run `updateUIView` and even style-load before the view has a size), and
  `update(annotation:)`. All guarded by `hasFramed` so it happens once per pin.
* `mapView(_:didUpdate userLocation:)` re-frames **exactly once** if the first framing had to fall
  back to the Man and a real on-playa fix arrives afterwards (`shouldReframeForUserLocation`).
* No annotation (event with no location, embargoed pin) → `brc_moveToBlackRockCityCenter` instead
  of silently doing nothing.
* No retain cycles: `MLNMapView.delegate` is weak, coordinator holds the adapter, adapter holds
  the map view.

New pure decision type `DetailMapFramingState` (same file) holds the rules:
`shouldFrame(_:)`, `shouldReframeForUserLocation(_:userLocationFramesAroundUser:)`,
`framesAroundUser(_:)`, `isEquivalent(_:_:)`.

`iBurn/MapViewAdapter.swift` — comment-only: the `styleLabelTapRecognizerName` doc no longer
claims a fresh adapter is built per SwiftUI update.

### Tests
`iBurnTests/DetailMapFramingTests.swift` (16 cases) covers initial framing gating, the
single-shot user-location re-frame, on/off-playa `framesAroundUser`, and annotation equivalence.

### Manual verification
1. Simulate a location on playa; open a camp from Nearby → pin and blue dot both framed with padding.
2. Open an art piece → same.
3. Open an event with no location → preview centered on the city, no crash.
4. Scroll the detail screen / toggle favorite (forces SwiftUI updates) → camera does not jump back out.

## Main-map event pins: callout text, Events toggle, refresh cadence (bugs 1–3)

### 1. "Hosted by Camp" callouts

`EventObject.primaryLocationString` returned the literal placeholders `"Hosted by Camp"` /
`"Located at Art"` — a bare `EventObject` only carries the host's *id*, so it could never
name it. The zoomed-in region path reached it because `MapRegionAnnotationFilter.annotations`
built pins with `PlayaObjectAnnotation(event: EventObject)` even though
`refreshRegionAnnotations()` had already fetched fully-joined `[EventObjectOccurrence]` and
thrown everything but the uids away.

- `EventObject.primaryLocationString` → `otherLocation` or nil (no placeholders).
- `EventObjectOccurrence.primaryLocationString` → `hostName · hostAddress`, falling back to
  the bare event's string. No embargo check (PlayaDB doesn't know about it); callers gate.
- `refreshRegionAnnotations()` now keeps the occurrences, indexed by event uid via the new
  pure `MapRegionAnnotationFilter.activeOccurrences(from:now:)` (running occurrence wins,
  else soonest start, `shouldShowOnMap` gated), and the filter builds pins with
  `PlayaObjectAnnotation(event: EventObjectOccurrence, now:)`.
- `PlayaObjectAnnotation.calloutSubtitle(for:now:canShowAddress:)` composes
  `host · address · time` with `" · "`, the same shape as `NearbyItem.accessoryLine`, with
  the address gated by `BRCEmbargo.canShowLocation(for:)` (overridable for tests). Weekday is
  still prepended to the time unless the occurrence is running.
  Example: `Palinka Lounge · 5:57 & Bodhi · 8:00 AM - 10:00 AM`.
- The bare-`EventObject` init is kept (`DetailViewModel` still uses it) but documented as a
  last resort and can no longer emit placeholder text.

### 2. Events toggle ignored by the region path

`MapRegionAnnotationFilter.annotations` gained `showEvents: Bool` and
`selectedEventTypeCodes: Set<String>?` (nil = all types, the `EventFilter` convention).
`refreshRegionAnnotations()` passes `UserSettings.showActiveEventsOnMap` and
`BRCEventType.eventTypeCodes(from: UserSettings.selectedEventTypesForMap)` — the same
derivation the observation layer uses in `PlayaDBAnnotationDataSource.startObserving()`.

### 3. Expired pins lingering

Two halves:

- **Observation layer.** The active-events observation used `EventFilter(happeningNow: true)`,
  whose predicate is frozen in SQL when the observation starts. It now queries today's window
  (`activeWindow: todayWindow(now:)`, the same trick the favourites layer already used) and
  keeps `TimedEventCandidate`s; `allAnnotations()` re-derives which are live via the new
  `PlayaDBAnnotationDataSource.occurrenceIsHappeningNow(startDate:endDate:now:)`. So a plain
  `reloadAnnotations()` now drops a finished pin — no observation restart needed.
  (`FavoriteEventCandidate` was renamed `TimedEventCandidate`, shared by both layers.)
- **Cadence.** New `iBurn/MapEventRefreshScheduler.swift`:
  - `MapEventRefreshBoundary.nextFireDate(occurrences:now:floor:ceiling:)` — pure. Candidates
    are the next minute boundary plus each occurrence's start, end, start − 30 min
    (starting-soon) and end − 15 min (ending-soon); soonest future one wins, clamped to
    `[15s, 60s]`.
  - `MapEventRefreshScheduler` arms one non-repeating `Timer` at a time (weak self), re-arms
    on fire, and also refreshes on `willEnterForeground`, `didBecomeActive` and
    `significantTimeChange`. Same shape as `EmbargoUnlockScheduler`.
  - `MainMapViewController` creates it in `viewWillAppear`, stops and releases it in
    `viewWillDisappear` (same lifecycle as `geocoderTimer`). Its refresh calls
    `refreshRegionAnnotations()` + `mapViewAdapter.reloadAnnotations()`.
  - `UserMapViewAdapter` exposes `trackedOccurrences` (what the last refresh drew) and
    `onRegionAnnotationsRefreshed`, so the scheduler re-arms after *any* refresh — a pan or
    the filter sheet's Done included.

### Signatures changed

```swift
// iBurn/UserMapViewAdapter.swift
static func MapRegionAnnotationFilter.annotations(
    from: [any PlayaDataObject], zoomLevel: Double,
    activeEventOccurrences: [String: EventObjectOccurrence],   // was activeEventUIDs: Set<String>
    showArtOnlyZoomedIn: Bool, showCampsOnlyZoomedIn: Bool,
    showEvents: Bool,                                          // new
    selectedEventTypeCodes: Set<String>?,                      // new
    artAllowed: Bool, campAllowed: Bool, now: Date = .present  // new
) -> [PlayaObjectAnnotation]

static func MapRegionAnnotationFilter.activeOccurrences(
    from: [EventObjectOccurrence], now: Date) -> [String: EventObjectOccurrence]   // new

// iBurn/PlayaObjectAnnotation.swift
convenience init?(event: EventObjectOccurrence, now: Date = .present)              // now: added
static func calloutSubtitle(for:now:canShowAddress: Bool? = nil) -> String         // canShowAddress: added
```

### Tests

`iBurnTests/MapEventPinTests.swift` (new, 14 cases) covers callout composition (host +
address + time, embargoed address dropped, weekday kept when not running, free-text
fallback), the `showEvents` / event-type gates, occurrence selection and expiry, and the
next-fire-date rules (minute boundary, nearest edge, floor, ceiling, status thresholds).
`iBurnTests/EmbargoTierTests.swift`'s `regionAnnotationTitles` helper was adapted to the new
signature (it synthesizes a running occurrence per active uid) so its existing cases stand.

---

## Phase 1 — OTA → PlayaDB updater (`DataUpdateService`)

Replaces `BRCDataImporter`'s YapDatabase over-the-air path with a PlayaDB-native
one. No Yap code deleted here; the launch path and the Settings screen simply stop
calling it.

### Files added

| File | Role |
|---|---|
| `iBurn/DataUpdates/DataUpdateService.swift` | `DataUpdateOutcome`, `DataUpdateError`, `.BRCDataUpdateDidImport`, `protocol DataUpdateService`, `DataUpdateServiceFactory` |
| `iBurn/DataUpdates/DataUpdateDependencies.swift` | `DataFetching` + `URLSessionDataFetcher`, `DataUpdatePreferencing` + `UserDefaultsDataUpdatePreferences`, `BundledDataProviding` + `BundledDataProvider`, `OTACacheEntry`, `OTADataCaching` + `OTADataFileCache` |
| `iBurn/DataUpdates/DataUpdateServiceImpl.swift` | the service |
| `Packages/PlayaDB/Sources/PlayaDB/Models/APIUpdateInfo+DataType.swift` | maps update.json entries → `DataObjectType` |
| `iBurnTests/DataUpdateServiceTests.swift` | 11 cases |
| `Packages/PlayaDB/Tests/PlayaDBTests/OutdatedDataTypesTests.swift` | 7 cases |

### Files changed

- `Packages/PlayaDB/.../PlayaDB.swift` / `PlayaDBImpl.swift`: new
  `outdatedDataTypes(comparedTo:)`; `needsImport(bundleUpdateData:)` now delegates to it,
  so bundle and server go through one newer-than comparison.
- `Packages/PlayaAPI/.../Models/UpdateInfo.swift`: `public typealias APIUpdateInfo = UpdateInfo`
  — PlayaDB also declares `UpdateInfo`, and `PlayaAPI.UpdateInfo` doesn't resolve because
  `PlayaAPI` is also an enum in that module.
- `iBurn/DependencyContainer.swift`: lazy `dataUpdateService`.
- `iBurn/BRCAppDelegate+Dependencies.swift`: `@objc checkForDataUpdates()` and
  `checkForDataUpdatesWithCompletion:`.
- `iBurn/BRCAppDelegate.m`: launch (was `loadUpdatesFromURL:`) and `handleBackgroundFetch:`
  now hop to the main queue and call the new service. `preloadExistingData` (Yap boot
  import) is untouched, for the deletion agent.
- `iBurn/DataUpdatesView.swift`: Yap-free. "Check for Updates" → `checkForUpdates(force: true)`,
  "Reset to Bundled Data" → `resetToBundledData()`, nerdy stats show only PlayaDB's
  `update_info`. `YapViewHandlerDelegateHandler` (declared here, used nowhere else) is gone.

### Behavior

1. Fetch `update.json`; parse with `APIParserFactory` (keys `art`/`camps`/`events`/`mv`,
   each `{file, updated}`; the legacy `tiles`/`points` keys are ignored, as PlayaAPI's model
   already did).
2. `playaDB.outdatedDataTypes(comparedTo:)` says which types are newer than `update_info`.
3. Download those, resolving `file` against the folder holding `update.json`; a value with a
   scheme is used verbatim (legacy tested `containsString:@"https"`). Each payload is written
   to `<Application Support>/PlayaDB/ota/<year>/<type>.json` with a `manifest.json` of
   `{file, updated}` stamps, written after the payload.
4. Import: every type is handed to `importFromData` (it is a full replace), choosing the
   cached download when it is at least as new as the bundled copy, bundled JSON otherwise.
   `updateData` is re-synthesized from the chosen sources, which is what keeps the next
   comparison — and `PlayaDBSeeder.needsImport` — from clobbering fresh OTA data with the
   older bundle.
5. `ColorPrefetcher.prefetchMissingColors` on a detached task, then `.BRCDataUpdateDidImport`.
   Lists/map refresh through GRDB observations.

Throttle: 24h (`UserDefaults.lastUpdateCheck`), stamped before the fetch like the legacy
importer. `force: true` bypasses both the throttle and `UserDefaults.areDownloadsDisabled`.
A cached download whose stamp matches the server is reused rather than re-fetched, so an
interrupted or failed-import update resumes.

**Tiles:** nothing to port. `BRCDataImporter.loadDataFromLocalURL:`'s tiles branch began with
`return;` ("No longer using static map tiles"), `BRCDataImporter.downloadOfflineTiles()` was a
TODO stub with no callers, and nothing observed `BRCDataImporterMapTilesUpdatedNotification`.

### Open questions

- `kBRCUpdatesURLString` is empty in this checkout's `BRCSecrets.m`, so the factory yields a
  service that throws `.missingUpdateURL`; the real URL must be present to exercise this
  end-to-end.
- The seeder's `seedIfNeeded()` Task and the launch OTA check can both call `importFromData`
  on the same launch (GRDB serializes them, so the result is a redundant import, not
  corruption). Worth collapsing once the Yap boot import is gone.

---

## Phase 2 — Delete legacy UIKit/Yap lists, feature flags, bridges

Scope: kill-switch UI, the two feature flags, the Yap↔PlayaDB bridges and the Yap list
plumbing. The Yap boot/import stack (`BRCDatabaseManager`, `BRCDataImporter`, Mantle
models, `iBurn-2026.zip`, Podfile) is untouched and belongs to phase 3.

### Deleted (git rm)

| File | Why |
|---|---|
| `iBurn/FavoritesViewController.swift` | kill-switch UIKit list (also held `FavoritesFilter`) |
| `iBurn/ArtListViewController.swift` | kill-switch UIKit list |
| `iBurn/EventListViewController.swift` | kill-switch UIKit list (last `ASDayPicker` user) |
| `iBurn/NearbyViewController.swift` | kill-switch UIKit list (also held `NearbyFilter`) |
| `iBurn/VisitListViewController.swift` | kill-switch UIKit list (also held unused `VisitFilter`) |
| `iBurn/AudioTourViewController.swift` | kill-switch UIKit list |
| `iBurn/MapPinListViewController.swift` | Yap-only, always empty on PlayaDB maps |
| `iBurn/ObjectListViewController.swift` | base class of the above |
| `iBurn/ListCoordinator.swift` | only wired the deleted lists |
| `iBurn/SearchDisplayManager.swift` | Yap search plumbing |
| `iBurn/YapViewHandler.swift` | Yap mappings/long-lived plumbing (see "kept" below) |
| `iBurn/YapTableViewAdapter.swift` | Yap table plumbing |
| `iBurn/YapDatabaseConnection+iBurn.swift` | `readReturning`, only used by `YapViewHandler` |
| `iBurn/YapDatabaseViewConnection+iBurn.{h,m}` | `BRCSectionRowChanges`, only used by `YapViewHandler` |
| `iBurn/FavoriteSyncService.swift` | the favorite/visit/notes mirror into Yap |
| `iBurnTests/YapPlayaDBBridgeTests.swift` | tested the deleted bridge |
| `iBurnTests/FavoriteSyncServiceTests.swift` | tested the deleted bridge |

### Feature flags

* `Preferences.FeatureFlags.useSwiftUILists` and `.usePlayaDBCalendarSync` removed, along
  with the "Use SwiftUI Lists" toggle in `FeatureFlagsView` and the `Preferences.Filters`
  enum (unused, and it referenced the deleted `FavoritesFilter`).
* `BRCPreferenceService.useSwiftUILists` (ObjC bridge) now returns a constant `true`.
  **Phase 3:** `BRCAppDelegate.m:112` still reads it to skip `ColorCache.prefetchAllColors`;
  delete both when the Yap boot stack goes (`prefetchAllColors` is now unreachable).
* Every read site keeps only the PlayaDB/SwiftUI branch:
  `BRCAppDelegate+Dependencies.swift` (favorites/nearby/events factories),
  `MoreViewController.swift` (art, camps, visit list, audio tour),
  `DetailDataService.swift`, `EventCalendarServiceFactory`.

### Calendar sync

`EventCalendarHookRouter`, `EventCalendarServiceFactory.isPlayaDBSyncEnabled` and the
ObjC `BRCCalendarSync` bridge are gone; `BRCDetailViewController.m`'s
`refreshCalendarEntry` branch went with them. The mirror used to be what triggered the
EKEvent reconcile, so the side effect moved to a new helper in `EventCalendarService.swift`:

```swift
enum EventCalendarSync {
    static func reconcile(favoriteIdentity: String, isFavorite: Bool)  // composite key or bare uid
}
```

Called from every event-favorite site that previously fanned out through the mirror:
`EventDataProvider.toggleFavorite`, `GlobalSearchViewModel.toggleFavorite`,
`VisiblePinsViewModel.toggleFavorite`, `FavoriteSeriesToastPresenter.performSeriesFavorite`,
`DetailViewModel.toggleFavorite` (`.event` / `.eventOccurrence`), and the watch-sync
callback in `DependencyContainer` (which previously reached the calendar only via the
mirror's hook).

`YapLegacyCalendarIdentifierStore` deleted; the `LegacyCalendarIdentifierStore` protocol is
kept (the service's one-way takeover logic and its tests still describe a real upgrade
path) and the factory now passes `nil`.

### Other edited files

* `iBurn/AnnotationDataSource.swift` — `YapViewAnnotationDataSource`,
  `YapCollectionAnnotationDataSource` and `BRCDataObject.annotation(transaction:)` removed;
  `StaticAnnotationDataSource`, `DataObjectAnnotation`, `AnnotationEmbargo`,
  `MapRegionDataSource`, `AggregateAnnotationDataSource` kept (detail mini map, list "show
  on map", `MapDetailViewController`, `MLNMapView+iBurn.m`).
* `iBurn/ListButtonHelper.swift` — the `DataObjectAnnotation` → `MapPinListViewController`
  branch dropped; every map now pushes `VisiblePinsHostingController`.
* `iBurn/BRCMediaDownloader.swift` — the Yap-driven background downloader (URLSession
  delegate, `downloadUncachedMedia`, `triggerColorComputationForFile`) deleted; the static
  path helpers (`localMediaURL`, `localCacheURL`, `fileName`, `imageFor*`) stay, since
  Swift *and* `BRCArtObject.m`/`BRCCampObject.m` still call them. No more `import YapDatabase`.
* `iBurn/BRCDatabaseManager.swift` — `LongLivedConnectionManager` moved here from
  `YapViewHandler.swift` (minus the view-handler fan-out) because `BRCDatabaseManager.{h,m}`
  still own it. Deletes with the boot stack in phase 3.
* `iBurn/ListView/NearbyViewModel.swift` — now declares `NearbyFilter` (was in the deleted
  `NearbyViewController`); `UserSettings.nearbyFilter` and `NearbyView` still use it.
* `iBurn/UserSettings.swift` — unused `favoritesFilter` accessor (typed `FavoritesFilter`)
  removed; `favoritesTypeFilter` keeps the same defaults key.
* `iBurn/DataObject.swift` — `YapViewHandler: DataObjectProvider` conformance removed;
  `DataObject` / `DataObjectProvider` kept for `SortedViewController` + `PageViewManager`.
* `iBurn/Detail/Services/DetailDataService.swift` — flag gate gone (the calendar service
  always owns EKEvents), the in-transaction legacy `refreshCalendarEntry` gone, and
  `FavoriteSyncServiceImpl.apiEventUID(fromYapUID:)` replaced by a new local
  `LegacyEventUID` helper (also used by `BRCDataObjectTableViewCell.playaDBUID(for:)`).
* `iBurn/Detail/ViewModels/DetailViewModel.swift` — `favoriteSyncService`,
  `syncFavoriteToYapDB`, `syncVisitStatusToYapDB`, `syncNotesToYapDB` removed; PlayaDB is
  the only write target for the PlayaDB subjects.
* `iBurn/DependencyContainer.swift` — `favoriteSyncService` and the watch-sync mirror gone;
  providers/toast presenter now take only `playaDB`.
* Providers/VMs stripped of `favoriteSync`: `Art/Camp/Event/MutantVehicleDataProvider`,
  `GlobalSearchViewModel`, `VisiblePinsViewModel`, `FavoriteSeriesToastPresenter`.
* `iBurn/Tabs/TabIdentifier.swift`, `iBurn/iBurn-Bridging-Header.h`,
  `iBurn/Preferences/*`, and stale doc comments in `FavoritesFilterable`,
  `AudioTourViewModel`, `VisitListViewModel`, `AudioTourHostingController`.
* Tests: `EventCalendarServiceTests` lost its Yap takeover fixtures (now a
  `StubLegacyCalendarIdentifierStore`, so the takeover cases still run), the hook-routing
  tests and the flag-default assertion, and no longer touches `BRCTestDatabaseHelper`;
  `GlobalSearchViewModelTests` mirror assertions became PlayaDB assertions;
  `VisitListViewModelTests` / `AudioTourViewModelTests` lost their stub mirrors.

### Kept deliberately (phase 3 work)

* **`BRCDetailViewController` + the whole legacy `BRCDataObject` detail path.** It is still
  reachable: `Preferences.UserInterface.useSwiftUIDetailView` is a *user-facing* toggle in
  Appearance settings (default on), and `DetailViewControllerFactory`,
  `PageViewManager`, `DetailPagingDataSource`, `MapViewAdapter` and
  `DetailActionCoordinator` all still resolve legacy objects. Removing it means removing
  that setting, which was outside this phase.
* Because of that: `SortedViewController`, `HostedEventsViewController` (pushed only from
  `BRCDetailViewController.m`), `BRCDataSorter` (+ `BRCDataSorterTests`),
  `BRCDataObjectTableViewCell` and the other Mantle cells/nibs, `UITableView+iBurn`,
  `PageViewManager`, `DataObject`/`DataObjectProvider`.
* **`DetailDataService` still writes Yap metadata** (`BRCDatabaseManager.readWriteConnection`)
  and reads everything through Yap transactions. Its API is `BRCDataObject`-shaped and the
  legacy detail screen reads back the same metadata, so making it PlayaDB-only writes would
  desync that screen. It already dual-writes PlayaDB; phase 3 deletes it with the models.
* `LongLivedConnectionManager`, `ColorCache`, `BRCMediaDownloader`'s path helpers,
  `DataObjectAnnotation` — all still referenced by kept code.

### Not verified

No build was run (a validation agent owns the compile + fixups). Files were syntax-checked
with `swiftc -parse` only. Most likely fixups: the `PeerSyncManager` callback signature in
`DependencyContainer` (the closure no longer captures `self`), and unused-variable warnings
in `GlobalSearchViewModel` / `VisiblePinsViewModel` after the mirror removal.

---

## Phase 3/4 — Delete the Yap boot/import stack, Mantle models, legacy detail path, pods

Everything that was left. The app, `iBurnTests` and `iBurnWatch` all compile with no
YapDatabase or Mantle anywhere in the tree.

### User-facing decision applied

`Preferences.UserInterface.useSwiftUIDetailView` and its **Appearance ▸ "Use New Detail
Screen"** toggle are gone; `DetailViewControllerFactory` only builds
`DetailHostingController`. The Appearance screen now has two sections (Theme, Image
Colors) instead of three.

### Deleted files

**Legacy UIKit detail path + cells**

| File | Why |
|---|---|
| `iBurn/BRCDetailViewController.{h,m}` | the legacy detail screen |
| `iBurn/HostedEventsViewController.swift`, `iBurn/SortedViewController.swift` | pushed only from it |
| `iBurn/PageViewManager.swift`, `iBurn/DataObject.swift` | `DataObject`/`DataObjectProvider` paging for Yap lists (the PlayaDB `DetailPagingDataSource` is unrelated and stays) |
| `iBurn/DayPicker.swift`, `iBurn/DayView.xib` | ASDayPicker-era day strip, unused |
| `iBurn/UITableView+iBurn.swift` | only registered the Mantle cell nibs |
| `iBurn/BRCDataObjectTableViewCell.{h,m,swift,xib}` | Mantle cells + nibs |
| `iBurn/BRCArtObjectTableViewCell.{h,m,xib}`, `iBurn/BRCEventObjectTableViewCell.{h,m,xib}`, `iBurn/ArtImageCell.{swift,xib}` | ditto |
| `iBurn/BRCDetailInfoTableViewCell.{h,m}`, `iBurn/BRCDetailCellInfo.{h,m}`, `iBurn/BRCRelationshipDetailInfoCell.{h,m}`, `iBurn/BRCEventRelationshipDetailInfoCell.{h,m}`, `iBurn/BRCSocialButtonsView.{h,m}` | legacy detail cells |
| `iBurn/MapDetailViewController.swift` | only reachable via `DetailAction.showMap(BRCDataObject)` |
| `iBurn/Detail/Services/DetailDataService.swift`, `iBurn/Detail/Protocols/DetailDataServiceProtocol.swift` | entirely `BRCDataObject`-shaped (see below) |
| `iBurn/Detail/Services/MockServices.swift`, `iBurn/Detail/Views/DetailView_Previews.swift` | Mantle-JSON fixtures + previews built on them |
| `iBurn/Detail/Services/AudioService.swift`, `iBurn/Detail/Services/EventEditService.swift` | `BRCArtObject` / `BRCEventObject` APIs with no remaining callers |

**Mantle model family + boot/import stack**

`BRCDataObject.{h,m,swift,_Private.h}`, `BRCDataObject+EmojiMarker.swift`,
`BRCDataObject+Events.swift`, `BRCDataObject+Relationships.{h,m}`,
`BRCYapDatabaseObject.{h,m}`, `BRCObjectMetadata.{h,m}`,
`BRCEventObject.{h,m,_Private.h}`, `BRCRecurringEventObject.{h,m}`,
`BRCArtObject.{h,m}`, `BRCArtObject+Emoji.swift`, `BRCCampObject.{h,m}`,
`BRCCampObject+Emoji.swift`, `BRCArtImage.{h,m}`, `BRCCampImage.{h,m}`,
`BRCCreditsInfo.{h,m}`, `BRCEventTime.{h,m}`, `BRCUpdateInfo.{h,m,swift}`,
`BRCGeocoder.{h,m}`, `BRCDatabaseManager.{h,m,swift}` (incl. `LongLivedConnectionManager`),
`BRCDataImporter.{h,m,swift,_Private.h}`, `BRCDataSorter.swift`.

**Seed + tests**

`iBurn/iBurn-2026.zip` (untracked/gitignored — deleted from disk),
`iBurnTests/BRCDataImportTests.swift`, `iBurnTests/BRCTestDatabaseHelper.swift`,
`iBurnTests/BRCDataSorterTests.swift`, `iBurnTests/DetailViewModelTests.swift`,
`iBurnTests/DetailServicesTests.swift`, `iBurnTests/DetailActionCoordinatorTests.swift`
(the last three exercised only the legacy `dataObject:` `DetailViewModel` init,
`DetailDataService`, and the removed `DetailAction` cases).

**Submodules:** `Submodules/YapDatabase` and `Submodules/ASDayPicker` (`git rm` + the
matching `.gitmodules` sections + `.git/modules/…`).

### Ported types (old → new)

| Old | New | Notes |
|---|---|---|
| `BRCEventType` (NS_ENUM in `BRCEventObject.h`) | `iBurn/BRCEventType.h` | standalone header, no Yap/Mantle imports |
| `BRCEventObject.swift` (`BRCEventType` extensions) | `iBurn/BRCEventType.swift` (git mv) | `BRCEventObject.allVisibleEventTypes: [NSNumber]` → `BRCEventType.allVisibleTypes: [BRCEventType]`; `BRCEventObject.stringForEventType(_:)` / `emojiForEventType(_:)` → the existing `description` / `emoji` properties. Call sites: `EventsFilterView`, `MapFilterView`, `UserSettings.selectedEventTypesForMap`, `BRCEventType+PlayaDB.eventTypeCodes(from:)` |
| `BRCEventObject.festivalStartDate()` | `YearSettings.eventStart` | one call site (`EmbargoPasscodeViewModel`) |
| `BRCImageColors : MTLModel` | `BRCImageColors : NSObject` | header-only change; it was never actually serialized after the metadata blobs went away |
| `BRCMapPoint : BRCYapDatabaseObject <MTLJSONSerializing, MLNAnnotation>` | `BRCMapPoint : NSObject <MLNAnnotation>` | rewritten `.h/.m`: no Mantle JSON transformers, no `yapCollection`. `yapKey` → **`uniqueID`** (a UUID until PlayaDB assigns the pin id). `BRCUserMapPoint.pinId` is now just `uniqueID`; `MapAnnotationRegistry.key(for:)` updated |
| `BRCCreditsInfo : MTLModel` | `struct CreditsInfo: Decodable` in `CreditsViewController.swift` | `JSONDecoder` instead of `MTLJSONAdapter` |
| `ColorCache` class (Yap iteration + metadata writes) | deleted; `ColorPrefetcher` already owns this | the `ColorTheme` / `copyParameters` UIKit extensions in `ColorCache.swift` stay |
| `BRCMediaDownloader.imageFor*` / `fileName(_:type:)` / `BRCMediaDownloadType` | deleted | only the static path helpers (`localMediaURL`, `localCacheURL`) remain; every caller is Swift/PlayaDB |
| `SortedViewController.geocodeNavigationBar()` + `NSString.brc_attributedLocationStringWithCrosshairs` (`BRCGeocoder.m`) + `CLLocation.currentLocation` | `iBurn/GeocodeNavigationBar.swift` | Swift port, same behaviour; used by `MainMapViewController` and `NearbyListHostingController` |
| `MockLocationService` / `MockTestDetailActionCoordinator` (app target) | `iBurnTests/DetailTestDoubles.swift` | keeps `PerOccurrenceFavoriteAppTests` alive |
| `BRCEmbargo.canShowLocationForObject:` | deleted | the Swift `BRCEmbargo.canShowLocation(for:)` PlayaDB overloads in `EmbargoNotification.swift` are the only tier check now |
| `BRCVisitStatus.swift` | kept as-is | already Yap/Mantle-free (only the doc comments mentioned Mantle) |

### Other edits

* **`BRCAppDelegate.{h,m}`** — Yap open + counts, `preloadExistingData`, the lazy
  `dataImporter` property, `handleEventsForBackgroundURLSession:`,
  `reduceCacheLimit`, the `BRCPreferenceService.useSwiftUILists` read and the dead
  `ColorCache.prefetchAllColors` branch are all gone. Launch now just does the
  `checkForDataUpdates` hop (guarded by `areDownloadsDisabled`).
  `BRCPreferenceService.useSwiftUILists` deleted from `PreferenceServiceFactory.swift`.
* **`DetailSubject`** — `.legacy(BRCDataObject)` case removed; every `switch` narrowed.
* **`DetailViewModel`** — the `dataObject:dataService:audioService:…` init and every
  legacy generator (`generateLegacyCellTypes`, `generateArtCells`/`generateCampCells`/
  `generateEventCells`, `generateLegacyCommonCells`, `generateLegacyMetadataCells`,
  `getLocationValue`, `getHostDescription`, `formatEventSchedule`, `getEventTimeColor`,
  `loadHostCampImage`/`loadHostArtImage`, `shouldShowMap`, `getEventThemeBRCColors`,
  `showEventEditor`, `showsCalendarButton`) deleted, along with `legacyMetadata`,
  `dataService` and `audioService`. 2071 → ~1460 lines.
* **`DetailCellType`** — `.mapView(BRCDataObject, metadata:)` and `.audio(BRCArtObject,…)`
  dropped (`.mapAnnotation` + `.audioTrack` are the PlayaDB equivalents);
  `DetailAction` lost `.showMap`, `.navigateToObject`, `.showEventsList`,
  `.showNextEvent`, `.playAudio`, `.showEventEditor`, `.showShareScreen`.
  `DetailView` lost the matching cases and `DetailAudioCell`.
* **`DetailMapViewRepresentable`** — the `dataObject:metadata:` initializer is gone;
  only `init(annotation:)` remains, so the mini-map is PlayaDB-only (`.mapAnnotation`).
  All of the Phase‑A framing work is untouched.
* **`AnnotationDataSource.swift`** — `DataObjectAnnotation`, its `MLNAnnotation` /
  `ImageAnnotation` conformances and `BRCDataObject.annotation(metadata:)` deleted.
  `AnnotationEmbargo` now only knows `PlayaObjectAnnotation`.
* **`MapViewAdapter`** — the `DataObjectAnnotation` branches in `viewFor:`,
  `leftCalloutAccessoryViewFor:`, `rightCalloutAccessoryViewFor:`,
  `calloutAccessoryControlTapped:`, `campUID(for:)` and `OffsettableAnnotation` are gone.
  `leftCalloutAccessoryViewFor:` is kept returning `nil` because `UserMapViewAdapter`
  overrides it (and `DetailMapViewRepresentable.Coordinator` forwards it).
* **`MLNMapView+iBurn.{h,m}`** — `brc_showDestinationForDataObject:metadata:…` removed.
* **`DetailActionCoordinator`** — `.showEventEditor`, `.showMap`, `.navigateToObject`,
  `.showEventsList`, `.showNextEvent`, `.playAudio`, `.showShareScreen` handling removed
  (all were `BRCDataObject`-typed; the PlayaDB equivalents — `.showMapAnnotation`,
  `.showShareURLScreen`, `.navigateToViewController` — already existed).
* **`ShareQRCodeView` / `ShareURLBuilder` / `BRCDeepLinkRouter`** — the
  `init(dataObject:)` pair, `ShareURLPayload.legacy(_:hostName:canShowLocation:)` and
  `BRCDataObject.generateShareURL()` deleted. `BRCMapPoint.generateShareURL()` stays.
* **`AudioServiceProtocol.swift`** — `AudioServiceProtocol` deleted; the file now holds
  only `LocationServiceProtocol` (minus `distanceToObject(_ object: BRCDataObject)`).
* **`BRCAudioPlayer`** — the three `@objc` `BRCArtObject` overloads dropped; the
  id/track-based API is what everything uses.
* **Bridging headers** — `iBurn/iBurn-Bridging-Header.h` trimmed to the 12 surviving
  headers (adds `BRCEventType.h`); `iBurnTests/iBurnTests-Bridging-Header.h` lost the
  `BRCDataImporter*` imports.
* **`EmbargoTierTests`** — the two legacy-annotation cases
  (`testLegacyCampAnnotationIsNil…`, `testLegacyArtAnnotationWaitsForGates`) removed;
  everything else stands.

### Podfile diff

```diff
-	pod 'YapDatabase', :path => 'Submodules/YapDatabase/YapDatabase.podspec'
-
 	pod 'CocoaLumberjack/Swift'
-	pod 'Mantle', '~> 2.0'
 	pod 'FormatterKit/LocationFormatter', '~> 1.8'
@@
-	pod 'ASDayPicker', :path => 'Submodules/ASDayPicker/ASDayPicker.podspec'
```

`pod install` → "Removing ASDayPicker / Mantle / YapDatabase"; 16 dependencies, 15 pods.
`Podfile.lock` lost 123 lines. LicensePlist's generated
`iBurn/Settings.bundle/com.mono0926.LicensePlist/{ASDayPicker,Mantle,YapDatabase}.plist`
were regenerated away by the build.

ASDayPicker was verified unused before removal (its last consumer,
`EventListViewController`, went in phase 2).

### Docs / CI touched

* `Docs/2026-07-18-api-data-refresh.md` — "Part C — Pre-populated YapDatabase seed" is
  now a RETIRED banner pointing at `playa-seed`; the `iBurn-2026.zip` regeneration steps
  are no longer part of the data-refresh procedure. The `iBurn/iBurn-*.zip` `.gitignore`
  rule is left in place so stale local copies stay untracked.
* `README.md` — the "YapDatabase + Mantle instead of Core Data" sentence now says GRDB /
  `Packages/PlayaDB`, and Mapbox → MapLibre.
* `.claude/skills/drive-app/SKILL.md` + `references/flows.md` — the
  `featureFlag.lists.useSwiftUI` kill-switch instructions, the Yap-mirror verification
  steps, the `MapPinListViewController` / `DataObjectAnnotation` split, the legacy
  `NearbyViewController` caveat, the "Use SwiftUI Lists" Feature Flags row and the Yap
  import log noise are all removed.
* No `.github/workflows/*` or `fastlane/` changes were needed — neither mentioned
  YapDatabase, Mantle, the seed zip or the two removed submodules.

### Build result

```
xcodebuild -workspace iBurn.xcworkspace -scheme iBurn        -destination "$DEST"  → success, 0 errors 0 warnings
xcodebuild build-for-testing -scheme iBurnTests              -destination "$DEST"  → success, 0 errors (9 libtool "no symbols" pod warnings)
xcodebuild -scheme iBurnWatch -destination generic/platform=watchOS Simulator      → success, 0 errors 0 warnings
```

Tests were **not** run (validation agent owns that). `git diff iBurn.xcodeproj/project.pbxproj`
contains no `DEVELOPMENT_TEAM` flip — only CocoaPods/Xcode regeneration churn
(`inputPaths = ()` removal in the Copy Pods Resources phase, an empty `exceptions = ()`
on the watch synced group, and `XCLocalSwiftPackageReference` comment renames).

### Survivors of `rg 'Yap|MTL|Mantle'`

Only prose: comments and doc-comments that explain what a type *used to be* or what a
PlayaDB path replaced — `Calendar/EventCalendarService.swift`,
`Calendar/LegacyCalendarIdentifierStore.swift`, `ListView/SearchResultIndex.swift`,
`ListView/RegionStatusService.swift`, `PlayaObjectAnnotation.swift`,
`BRCMediaDownloader.swift`, `BRCMapPoint.h`, `BRCEventType.h`,
`GeocodeNavigationBar.swift`, `Packages/PlayaDB/.../{PlayaDBImpl,EventFavoriteKey,
EventCalendarEntry,VisitStatus}.swift`, plus a few test comments. No imports, no types,
no symbols. `iBurn/Settings.bundle/com.mono0926.LicensePlist.{plist,latest_result.txt}`
still list the removed pods until the next LicensePlist run rewrites them (the build
already deleted the three per-pod plists).

### Known follow-ups

* `DetailPageViewController.swift`'s doc comment still mentions `BRCDetailViewController`
  as one of its two child types; it now only ever hosts `DetailHostingController`.
* `EKEventEditViewDelegate` conformance is still on `DetailActionCoordinatorImpl` even
  though nothing presents an `EKEventEditViewController` from the detail screen any more
  (the "add to calendar" button went with the legacy path; `EventCalendarService` owns
  EKEvents for favorited events). Harmless, but removable.
* `DetailActionCoordinatorTests` was deleted rather than rewritten — the surviving
  PlayaDB actions (`.share`, `.editNotes`, `.showMapAnnotation`, `.showShareURLScreen`)
  have no direct unit coverage now.

---

## Phase 5 — Validation pass (tests + drive-app)

### Test results

| Suite | Result |
|---|---|
| `xcodebuild test -scheme iBurnTests` (iPhone 17 Pro Max, iOS 26.5) | **647 passed, 0 failed** (after the fix below; first run was 646/1) |
| `swift test --package-path Packages/PlayaDB` | **365 passed, 0 failed** |
| `swift test --package-path Packages/PlayaAPI` | **74 passed, 0 failed** |
| `xcodebuild -scheme iBurnWatch -destination generic/platform=watchOS Simulator` | **success, 0 errors 0 warnings** |

New suites confirmed to run and pass (targeted run, 113 tests total):
`MapEventPinTests` (13), `DetailMapFramingTests` (18), `DataUpdateServiceTests` (24),
`EventCalendarServiceTests` (36), `GlobalSearchViewModelTests` (16),
`PerOccurrenceFavoriteAppTests` (6). `OutdatedDataTypesTests` (7) confirmed inside the
PlayaDB package run.

`xcodebuild test` intermittently aborts with
`FBSOpenApplicationErrorDomain Code=6 "Application failed preflight checks" (Busy)` before
any test runs — a simulator launch race, not a test failure. Re-run (booting the sim
first with `xcrun simctl boot <UDID>` helps); xcsift reports it as `status: failed` with
`failed_tests: 0` and no `passed_tests` line, which is the tell.

### The one real failure, and the fix

```
/Users/chrisbal/Documents/Code/iBurn-iOS/iBurnTests/MapAnnotationRegistryTests.swift:44
-[iBurnTests.MapAnnotationRegistryTests testCopiesOfTheSamePinShareAKeyDespiteDifferentYapKeys]
XCTAssertNotEqual failed: ("row-1") is equal to ("row-1") - precondition: separate objects
```

Stale assertion left by the `BRCMapPoint` rewrite. Under Mantle/Yap, `yapKey` was a random
UUID per instance and `pinId` was a separate stored property, so two copies of one row
really did differ in `uniqueID`. Phase 3 collapsed them —
`BRCUserMapPoint.pinId` is now `{ get { uniqueID } set { uniqueID = newValue } }` — so the
test's *precondition* became impossible by construction. The registry logic it guards is
unaffected (it keys on `pinId`, which is exactly what the dedup wants).

* `iBurnTests/MapAnnotationRegistryTests.swift` — renamed
  `testCopiesOfTheSamePinShareAKeyDespiteDifferentYapKeys` →
  `testSeparateCopiesOfTheSamePinShareAKey`; precondition is now
  `XCTAssertFalse(placed === fromDatabase)` (object identity, which is what the test
  actually needs); helper doc comment corrected.
* `iBurn/MapAnnotationRegistry.swift` — comment-only: `key(for:)` no longer claims
  "`uniqueID` is a fresh random UUID every time the pin is rebuilt from PlayaDB".

No other source changes were needed.

### drive-app pass (iPhone 17 Pro Max, iOS 26.5, `iBurn (Mock Date)`, sim location 40.79126,-119.21107 = Orphan Asylum)

Fresh install → onboarding (location / notifications / calendar all granted). The on-playa
fix plus the festival mock date (`2026-09-04T11:00-0700`) unlocked both embargo tiers
("Data Unlocked" alert), so the map draws real placement.

| # | Check | Result |
|---|---|---|
| a | Event pin callout | **PASS** — "The After Spiral Camp Party" / "Maison Phi · 10:00 B Plaza · 11:00 AM - 2:00 PM". Every visible pin's AX value has the same `host · address · time` shape. No "Hosted by Camp" anywhere. |
| b | Events filter off → Done | **PASS** — all event pins vanish live; still none after zooming to ≥16 and ≥17 over a camp with 11 live events. Back on → pins return live, correct callouts. |
| c | Expiry + foreground | **PASS** — suspend, advance `BRCMockDateValue` 11:00 → 11:35, `simctl launch` (same pid). "Fanning delight" and "Masking in the sun" (both end 11:30) are gone; "Designed to Feel: Neuroaesthetics · **Friday** 12:00 PM - 1:00 PM" and other noon starts appear with the weekday prefix (not running). No crash. The `Timer` half is not exercisable under a mock date (it fires on the real clock while `Date.present` is pinned) — `MapEventPinTests` covers it. |
| d | Detail mini-map | **PASS** for camp, art and event. AX shows "Zoom 14x." with both a "You Are Here" button and the object's annotation; screenshots show the blue dot and the pin framed together. Scrolling, toggling the heart and presenting/dismissing the share sheet all leave both framed. |
| e | More → Data Updates | **PASS** — "Check for Updates" → red "Update failed: No update server URL is configured." (empty `kBRCUpdatesURLString`), no crash. "Reset to Bundled Data" → "Reset complete"; nerdy stats read Art 332 / Camp 1,184 / Event 3,412, all `complete`; lists and map repopulate; favorites survive. |
| f | Cold-launch sanity | **PASS** — Favorites / Art / Camps / Mutant Vehicles / Audio Tour / Recently Viewed / Events all populate; camp + event occurrence favorited and reflected everywhere; detail share sheet (QR + AirDrop copy) opens; global search "pancakes" returns FTS hits across art and camps. |

On-device DB after the pass (`PlayaDB.sqlite`, WAL): art 332, camp 1184, event 3412,
occurrences 6565; `object_metadata` holds `camp|a1XVI00000FP3DN2A1|1` and
`event|UYnXJzbxhaYAd3BHMXen#2026-09-04T07:00:00Z|1` (the composite `EventFavoriteKey`,
right half matching the occurrence's UTC start), and exactly one `event_calendar_entries`
row. All invariants from the drive-app skill hold.

Screenshots: `/private/tmp/claude-501/-Users-chrisbal-Documents-Code-iBurn-iOS/512d7797-1035-474f-bf33-a5b2426e2613/scratchpad/00..14-*.jpg` (session scratchpad, transient).

### Observations that are **not** regressions from this work

* **Events tab reads "No events found" under a mock date** unless "Show Expired Events" is
  on. PlayaDB's `notExpired(at: Date = Date())` / `happeningNow(at:)` take the real clock —
  the package has no `Date.present` — so every 2026 occurrence is "expired" against the
  post-festival wall clock. `QueryInterfaceRequest+DataObject.swift` is untouched by this
  branch.
* **The map's region path never pins an already-running event.**
  `refreshRegionAnnotations()` calls `fetchUpcomingEvents(within: 1, from: now)`, whose SQL
  is `start_time > now`, so `activeOccurrences(from:now:)` only ever sees
  starting-within-30-minutes rows. Happening-now pins come from
  `PlayaDBAnnotationDataSource`. Pre-existing (the `within: 1` call is unchanged in the
  diff), but the `shouldShowOnMap` "happening now" branch in `activeOccurrences` is
  therefore dead for the region path — worth a look later.
* **Nearby tab shows "Location unavailable" on relaunches** while the map's blue dot and
  the detail screen's "Distance:" row are both fine. `CoreLocationProvider` polls
  `BRCAppDelegate.shared.locationManager.location` and never starts it; only onboarding's
  `requestLocationPermission` and `locationManagerDidChangeAuthorization` call
  `startUpdatingLocation`. MapLibre and `Detail/Services/LocationService` each own their
  own started manager, which is why they work. Nothing in this branch touches
  `LocationProvider.swift`, `DependencyContainer`'s wiring or those `BRCAppDelegate` lines
  (`NearbyViewModel`'s only diff is the additive `NearbyFilter` enum move). Longstanding;
  filed here rather than fixed.

### Source control

`git diff iBurn.xcodeproj/project.pbxproj` contains **no** `DEVELOPMENT_TEAM` flip after
the full test + build + drive pass — only the CocoaPods/Xcode regeneration churn already
noted in Phase 3/4. Nothing was committed.

### Flow docs updated

`.claude/skills/drive-app/references/flows.md` — §3 mock-date/"Show Expired Events" trap;
§6 events-filter default-off, the two event-pin layers and their coverage, the
`host · address · time` callout contract, the refresh scheduler and how to drive its
foreground half, the Nearby "Location unavailable" note; §7 the mini-map two-point framing
contract; new §11 Data Updates; "Last verified" bumped to 2026-09-12.
`.claude/skills/drive-app/SKILL.md` — seeded row counts refreshed to the Aug 27 seed
(art 332, camp 1184, event 3412, occurrences 6565).

---

## Phase 6 — Follow-up round (main session, no subagents)

Three findings from the validation pass plus one default change, each its own commit:

| Commit | Change |
|---|---|
| 74ebad76 | `BRCAppDelegate.m`: new `startLocationUpdatesIfAuthorized`, called after the manager is created and in `applicationDidBecomeActive`. Fixes Nearby "Location unavailable" on relaunch. Not simulator-verified this round (unit-untestable; tests + build pass). |
| dff709ec | `PlayaDB.fetchActiveEvents(startingWithin:from:)` (`end_time > now && start_time <= now + window`) replaces `fetchUpcomingEvents` in `UserMapViewAdapter.refreshRegionAnnotations`, so an event already in progress gets a region pin. New `PlayaDBClock.now` is the default clock for `notExpired`/`happeningNow`/`startingWithin`/`fetchCurrentEvents`/`fetchUpcomingEvents`; `DependencyContainer` sets it to `{ Date.present }` so the Mock Date scheme moves the Events tab. Tests: `ActiveEventsAndClockTests` (3). |
| 05536f1e | `UserSettings.showActiveEventsOnMap` defaults to `true`. |

Results: PlayaDB package 368 pass; iBurnTests 647 pass. LicensePlist Settings.bundle was already clean (build phase regenerated it in d956ac2e).

Left for later: Dependabot (BlackRockCityPlanner 72 vulns, iBurn-iOS 8), MapLibre 6.18.0-patch0 pin revisit, `EKEventEditViewDelegate` dead conformance on `DetailActionCoordinatorImpl`, unit coverage for surviving `DetailAction` cases.
