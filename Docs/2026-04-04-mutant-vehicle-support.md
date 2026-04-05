# Mutant Vehicle Support

## Problem
iBurn had no support for mutant vehicles, a major category of Burning Man content. The `mv.json` data file was already added to the bundle but the app had no way to parse, store, or display it.

## Solution
Added mutant vehicles as a first-class data type in the PlayaDB layer (GRDB, no legacy YapDatabase), with full UI support for browsing, searching, favoriting, and viewing details.

## Key Design Decisions
- **PlayaDB-only**: No legacy `BRCMutantVehicleObject` Obj-C class. MVs are new and don't need backward compatibility with YapDatabase.
- **No GPS/location**: Mutant vehicles are mobile, so no spatial indexing or map pins.
- **Normalized tags**: `mv_tags` join table for efficient tag-based filtering.
- **Emoji**: 🚐 for mutant vehicles.

## Files Created (9)

### PlayaAPI Package
- `Packages/PlayaAPI/Sources/PlayaAPI/Models/MutantVehicle.swift` - API model + `MutantVehicleImage`

### PlayaDB Package
- `Packages/PlayaDB/Sources/PlayaDB/Models/MutantVehicleObject.swift` - DB model + `MutantVehicleImage` + `MutantVehicleTag`
- `Packages/PlayaDB/Sources/PlayaDB/Filters/MutantVehicleFilter.swift` - Filter with year, search, favorites, tag

### App UI
- `iBurn/ListView/MutantVehicleDataProvider.swift` - ObjectListDataProvider for MVs
- `iBurn/ListView/MutantVehicleListViewModel.swift` - Typealias
- `iBurn/ListView/MutantVehicleListView.swift` - SwiftUI list + filter sheet
- `iBurn/ListView/MutantVehicleListHostingController.swift` - UIKit bridge
- `iBurn/MutantVehicleObject+Emoji.swift` - Emoji constant

## Files Modified (15+)

### PlayaAPI
- `Identifiers.swift` - Added `MutantVehicleID`
- `APIParser.swift` - Added `parseMutantVehicles`
- `BundleDataLoader.swift` - Added `loadMutantVehicles`

### PlayaDB
- `DataObject.swift` - Added `.mutantVehicle` to `DataObjectType`
- `AnyDataObjectID.swift` - Added `.mutantVehicle(MutantVehicleID)` case
- `TypedIdentifiers.swift` - Added `MutantVehicleObject: Identifiable`
- `PlayaDB.swift` - Added fetch/observe/import protocol methods
- `PlayaDBImpl.swift` - Schema (3 tables), FTS5, import, search, favorites, observe
- `ObjectMetadata.swift` - Added `forMutantVehicle` convenience

### App
- `PlayaDBSeeder.swift` - Loads and seeds MV data
- `DependencyContainer.swift` - Added data provider + factory
- `DetailSubject.swift` - Added `.mutantVehicle` case
- `DetailViewModel.swift` - Full MV detail support
- `DetailViewControllerFactory.swift` - Added MV factory
- `PlayaObjectAnnotation.swift` - Added MV case (always nil)
- `MoreViewController.swift` - Added "Mutant Vehicles" menu entry
- `DisplayableObject.swift` - Added MV conformance
- `FavoritesFilterable.swift` - Added MV filter conformance

### Data
- `update.json` - Added `"mv"` entry

## Database Schema (New Tables)
- `mv_objects` - Main table (uid, name, year, url, contact_email, hometown, description, artist, donation_link)
- `mv_images` - Images (id, mv_id, thumbnail_url)
- `mv_tags` - Normalized tags (id, mv_id, tag)
- `mv_objects_fts` - FTS5 virtual table for search

## Verification
1. Build: `xcodebuild -workspace iBurn.xcworkspace -scheme iBurn ...`
2. Navigate: More > Mutant Vehicles
3. Test: Search, favorite, view detail, global search includes MVs

## Additional Implementation
- `iBurn/MutantVehicleImageDownloader.swift` -- Downloads MV thumbnails on app launch, caches as `<uid>.jpg` for `RowAssetsLoader` compatibility
- `PlayaDB.fetchMutantVehicleImageURLs()` -- Protocol method to get uid->URL mapping from `mv_images` table
- Wired up in `DependencyContainer` to run automatically

## Remaining Work
- Add unit tests for MV JSON parsing and DB import
- Consider adding tag-based filtering UI (chips/picker)
- `BRCGreenPin` asset doesn't exist yet -- add or use existing pin color

---

# Favorites View Migration: YapDB → PlayaDB + SwiftUI

## Problem
The Favorites tab used `FavoritesViewController`, a UIKit view built on YapDatabase filtered views with 60-second polling. It only supported Art, Camps, and Events. Mutant Vehicles (newly added) were not shown. The view needed migration to PlayaDB for reactive updates and consistency with the rest of the SwiftUI migration.

## Solution
Created a new SwiftUI `FavoritesView` + `FavoritesViewModel` that observes all 4 object types (Art, Camps, Events, MVs) via PlayaDB, with reactive GRDB updates (no polling). Feature-flagged behind `useSwiftUILists` (same as Events migration).

## Key Design Decisions
- **Dedicated FavoritesViewModel** (not generic `ObjectListViewModel`) because favorites is multi-type. Same precedent as `EventListViewModel`.
- **4 parallel GRDB observation streams** -- each fires independently, simpler than merged query.
- **`FavoriteItem` enum** for type-safe multi-type rendering at the view layer.
- **`FavoritesTypeFilter`** extends the old `FavoritesFilter` with `.mutantVehicle` case. Uses same UserDefaults key for backward compat.
- **Reuses existing views**: `EventRowView`, `MediaObjectRowView`, `FavoritesFilterView`.

## Files Created (4)
- `iBurn/ListView/FavoriteItem.swift` - `FavoriteItem` enum, `FavoriteSection`, `FavoritesTypeFilter`
- `iBurn/ListView/FavoritesViewModel.swift` - Multi-type VM with 4 observations, search, host resolution
- `iBurn/ListView/FavoritesView.swift` - SwiftUI view with segmented control, sectioned list, filter/map buttons
- `iBurn/ListView/FavoritesListHostingController.swift` - UIKit bridge for tab bar

## Files Modified (4)
- `iBurn/DependencyContainer.swift` - Added `makeFavoritesViewModel()` factory
- `iBurn/BRCAppDelegate+Dependencies.swift` - Added `createFavoritesViewController()` with feature flag
- `iBurn/BRCAppDelegate.m` - Replaced inline favorites setup with `createFavoritesViewController()` call
- `iBurn/UserSettings.swift` - Added `favoritesTypeFilter` property (same key, supports MV case)

## Verification
1. Build succeeds
2. Enable `useSwiftUILists` feature flag in debug settings
3. Favorites tab shows segmented control (All/Art/Camps/Events/Vehicles)
4. Favorited items appear grouped by type with reactive updates
5. Search, filter sheet, map button, detail navigation all work
6. Disable feature flag → legacy FavoritesViewController still works

---

# Global Search Migration: YapDB → PlayaDB FTS5 + SwiftUI

## Problem
The global search (map tab) used `SearchDisplayManager`, tightly coupled to YapDatabase's `YapDatabaseSearchResultsView` and `YapDatabaseSearchQueue`. It only searched Art, Camps, and Events (no Mutant Vehicles). PlayaDB already had `searchObjects(_:)` with FTS5 across all 4 types.

## Solution
Created a reusable `GlobalSearchView` + `GlobalSearchViewModel` backed by PlayaDB FTS5, integrated into `MainMapViewController` via `UISearchController.searchResultsController`.

## Key Design Decisions
- **SwiftUI results inside UISearchController** -- preserves native iOS search UX (bar in nav, dimming) while using SwiftUI for rendering
- **Debounced search** (0.3s) via `Task.sleep` in the ViewModel, minimum 2 chars
- **Results grouped by type** (Art/Camps/Events/Vehicles) with section headers
- **Type-specific rows**: `MediaObjectRowView` for art/camp/MV, custom event row with emoji + type label
- **Standalone reusable view** -- can be embedded in any context

## Files Created (4)
- `iBurn/ListView/SearchResultItem.swift` - `SearchResultItem` enum, `SearchResultSection`
- `iBurn/ListView/GlobalSearchViewModel.swift` - VM with debounced FTS5 search via `playaDB.searchObjects(_:)`
- `iBurn/ListView/GlobalSearchView.swift` - SwiftUI view with sectioned results, empty states
- `iBurn/ListView/GlobalSearchHostingController.swift` - UIKit bridge for UISearchController integration

## Files Modified (3)
- `iBurn/MainMapViewController.swift` - Replaced `SearchDisplayManager` with `GlobalSearchHostingController` + `UISearchController`, removed `YapTableViewAdapterDelegate`
- `iBurn/DependencyContainer.swift` - Added `makeGlobalSearchViewModel()` and `makeGlobalSearchHostingController()` factories
- `iBurn/ListView/DisplayableObject.swift` - Added `EventObject: DisplayableObject` conformance

## Verification
1. Build succeeds
2. Map tab → tap search bar → type query → results appear grouped by type
3. Tap result → navigates to detail view
4. All 4 types searchable (including MVs, which YapDB search didn't support)

---

# Map Annotations Migration: YapDB → PlayaDB

## Problem
The map tab's annotation data sources (`FilteredMapDataSource`) used 4 `YapViewAnnotationDataSource` instances to show art, camps, events, and favorites on the map. These were synchronous reads from YapDatabase views. PlayaDB already had observation APIs and `PlayaObjectAnnotation` had convenience initializers for all types.

## Solution
Replaced YapDB annotation data sources with a `PlayaDBAnnotationDataSource` using a cache-and-observe pattern: GRDB observations push data changes, cached annotations are returned synchronously via the existing `AnnotationDataSource` protocol, and a delegate notifies the map to reload.

## Key Design Decisions
- **Cache-and-observe pattern**: `AnnotationDataSource.allAnnotations()` stays synchronous. GRDB observations update per-category caches asynchronously, then merge and notify via delegate.
- **6 separate observations**: art, camps, events, fav-art, fav-camps, fav-events. Each fires independently, can be enabled/disabled per UserSettings.
- **Embargo via `BRCEmbargo.allowEmbargoedData()`**: Global boolean check. If false, all observations produce empty arrays.
- **Event type filtering at query level**: `EventFilter.eventTypeCodes` with `BRCEventType.playaDBCode` mapping handles type filtering in the DB.
- **User pins stay on YapDB**: `BRCUserMapPoint` is deeply coupled to YapDB save/load/edit, separate migration scope.
- **No changes to `MapViewAdapter` or `PlayaObjectAnnotation`**: Already fully compatible with PlayaDB annotations.

## Files Created (2)
- `iBurn/PlayaDBAnnotationDataSource.swift` - Cache-and-observe data source with 6 GRDB observations
- `iBurn/BRCEventType+PlayaDB.swift` - Maps `BRCEventType` enum to PlayaDB event type code strings

## Files Modified (2)
- `iBurn/FilteredMapDataSource.swift` - Rewritten to use `PlayaDBAnnotationDataSource` + `YapCollectionAnnotationDataSource` (user pins). Now takes `PlayaDB` in init.
- `iBurn/MainMapViewController.swift` - Injects `PlayaDB` into `FilteredMapDataSource`, wires reactive `onAnnotationsChanged` callback, wires `onPlayaInfoTapped` for detail navigation, filter changes call `updateFilters()` instead of recreating data source, removed YapDB extension registration observer.

## Verification
1. Build succeeds (0 errors)
2. All 43 iBurnTests pass
3. Map tab: art/camp/event pins appear based on filter settings
4. Filter changes: toggle art/camps/events → pins update reactively
5. Favorites: favorite an item → pin appears on map
6. Callout: tap pin → info button → detail view opens
7. User pins (home, bike, star) still work via YapDB

---

# Nearby View Migration: YapDB → PlayaDB + SwiftUI

## Problem
The Nearby tab (`NearbyViewController`) was a UIKit view backed by YapDB R-Tree spatial queries, `BRCDataSorter` for sorting, and `BRCDataObjectTableViewCell` for rendering. It used 60-second polling, had no reactive updates, and couldn't benefit from PlayaDB's observation APIs.

## Solution
Created SwiftUI `NearbyView` + `NearbyViewModel` backed by PlayaDB spatial observations with 3 parallel observation streams (art, camps, events) using region filters. Feature-flagged behind `useSwiftUILists`.

## Key Design Decisions
- **Observation with region filter + restart on change**: Efficient DB-level spatial filtering. Observations restart only on significant location change (>50m), stepper change, or warp apply.
- **Client-side event time filtering**: `EventFilter.happeningNow` can't accept warped time. Solution: observe all events in region (`includeExpired: true`), client-side filter for `startTime <= effectiveDate && endTime > effectiveDate`.
- **Reuse existing `TimeShiftViewController`**: Already SwiftUI modal, presented from hosting controller.
- **Distance sorting**: Art/camps sorted by `CLLocation.distance(from:)`, events by `startTime`.
- **Feature-flagged**: `useSwiftUILists` gates new view, legacy `NearbyViewController` as fallback.

## Files Created (4)
- `iBurn/ListView/NearbyItem.swift` - `NearbyItem` enum, `NearbySection`, `NearbySectionID`
- `iBurn/ListView/NearbyViewModel.swift` - Location-dependent VM with 3 region-filtered observations, distance sorting, client-side event filtering, host resolution, time shift support
- `iBurn/ListView/NearbyView.swift` - SwiftUI view with distance stepper, type filter, warp button, sectioned list
- `iBurn/ListView/NearbyListHostingController.swift` - UIKit bridge with detail/map/time-shift navigation, geocoded nav bar

## Files Modified (3)
- `iBurn/DependencyContainer.swift` - Added `makeNearbyViewModel()` factory
- `iBurn/BRCAppDelegate+Dependencies.swift` - Added `createNearbyViewController()` with feature flag
- `iBurn/BRCAppDelegate.m` - Replaced inline NearbyViewController creation with `createNearbyViewController` call

## Verification
1. Build succeeds (0 errors)
2. All 43 iBurnTests pass
3. Nearby tab: shows art/camps/events sorted by distance/time within search radius
4. Stepper: adjusting radius updates results reactively
5. Type filter: segmented control filters by type
6. Time Shift: Warp → TimeShiftViewController → apply → results update
7. Map button: shows nearby results on map
8. Feature flag off: legacy NearbyViewController still works

---

# Detail Data Service Dual-Write: YapDB ↔ PlayaDB Sync

## Problem
During the YapDB→PlayaDB migration, favorites and user notes set in one database were invisible to views backed by the other. Legacy detail views (from deep links, map annotation taps, page swiping) wrote to YapDB only. New SwiftUI detail views wrote to PlayaDB only.

## Solution
Dual-write: every favorite/note change writes to both YapDB and PlayaDB, keeping both databases in sync during the transition.

## Key Design Decisions
- **`setFavorite(_:Bool, for:)` API**: Added to PlayaDB protocol (vs `toggleFavorite`-then-check) for reliable sync — avoids race conditions.
- **Fire-and-forget sync**: Secondary write is best-effort (logged errors, no throw). Primary write blocks; sync runs in background `Task`.
- **No MV sync**: Mutant vehicles are PlayaDB-only, no YapDB equivalent exists.
- **Typed column constants**: Replaced raw `Column("string")` with `ObjectMetadata.Columns` enum in PlayaDB metadata queries.

## Files Created (0)

## Files Modified (5)

### PlayaDB Package
- `PlayaDB.swift` — Added `setFavorite(_:Bool, for:)` protocol method
- `PlayaDBImpl.swift` — Implemented `setFavorite`, migrated `toggleFavorite`/`isFavorite` to use `ObjectMetadata.Columns` constants

### App
- `DetailDataService.swift` — Accepts `PlayaDB?`, syncs favorites/notes to PlayaDB after YapDB writes
- `DetailViewModel.swift` — Added `syncFavoriteToYapDB`/`syncNotesToYapDB` helpers, called after PlayaDB writes for art/camp/event cases
- `DetailViewControllerFactory.swift` — Injects `PlayaDB` into `DetailDataService` via `BRCAppDelegate.shared.dependencies.playaDB`
- `BRCDataObjectTableViewCell.swift` — Fire-and-forget PlayaDB sync after YapDB favorite toggle

## Files Deleted (2)
- `LegacyDataStore.swift` — Zero callers, dead code
- `LegacyFavoritesStoring.swift` — Zero callers, dead code

## Verification
1. Build succeeds (0 errors)
2. All iBurnTests pass
3. Favorite in SwiftUI detail → appears in legacy views (and vice versa)
4. User notes in SwiftUI detail → persist in legacy detail (and vice versa)

---

# Detail Read Paths Migration: YapDB → PlayaDB

## Problem
`DetailViewModel` had two init paths: a legacy path that read all data from YapDB via `DetailDataService`, and a PlayaDB path that read directly from PlayaDB. Several call sites (deep links, map callouts, relationship navigation) still entered through the legacy path because they had a `BRCDataObject` in hand, causing detail views to read from YapDB instead of PlayaDB.

## Solution
Added an async bridge factory method to `DetailViewControllerFactory` that resolves a `BRCDataObject` to its PlayaDB equivalent by UID, then creates the detail view via the PlayaDB path. Migrated 3 of 4 legacy call sites; deferred PageViewManager (requires synchronous VC creation from UIPageViewControllerDataSource).

## Key Design Decisions
- **Async bridge**: All 3 migrated call sites already supported async (Task blocks or DispatchQueue.main.async). No need for blocking synchronous reads.
- **Fallback to legacy**: If PlayaDB fetch fails, falls back to existing legacy path. Safe during transition.
- **PageViewManager deferred**: UIPageViewControllerDataSource requires synchronous VC return. Will migrate naturally when list views move to PlayaDB.
- **No PlayaDB protocol changes**: All needed fetch methods already existed.

## Files Modified (4)
- `DetailViewControllerFactory.swift` — Added `createDetailViewController(for:playaDB:) async` bridge method
- `BRCDeepLinkRouter.swift` — Replaced YapDB lookup with PlayaDB async fetch in `navigateToObject`
- `MapViewAdapter.swift` — Map callout info button now uses async PlayaDB bridge
- `DetailActionCoordinator.swift` — Relationship navigation wrapped in Task, uses async PlayaDB bridge

## Files Unchanged
- `PageViewManager.swift` — Deferred (synchronous UIPageViewControllerDataSource requirement)
- `DetailDataService.swift` — Read methods retained for PageViewManager's legacy path

## Verification
1. Build succeeds (0 errors)
2. All iBurnTests pass
3. Deep links open detail views via PlayaDB path
4. Map callout info button opens detail views via PlayaDB path
5. Relationship navigation in detail view uses PlayaDB path
6. Page swiping in legacy list views still works (unchanged)

---

# User Map Pins Migration: YapDB → PlayaDB

## Problem
User map pins (`BRCUserMapPoint` — home, bike, star) were stored in YapDB. All CRUD operations (create, drag-save, rename, delete) and reads (map display, "find nearest" navigation) went through YapDB connections.

## Solution
Added a `user_map_pins` table to PlayaDB with a `UserMapPin` GRDB record model. All pin storage now goes through PlayaDB with GRDB observations for reactive map updates. `BRCUserMapPoint` remains as the MLNAnnotation class on the map; conversion helpers bridge between the storage and annotation models.

## Key Design Decisions
- **Keep `BRCUserMapPoint` as annotation class**: Deeply integrated with MapLibre drag/callout/view system. Only storage moved to PlayaDB.
- **Bridge pattern**: `UserMapPin` (GRDB struct) ↔ `BRCUserMapPoint` (MLNAnnotation) via conversion helpers with `pinId` associated object for identity tracking.
- **Reactive observation**: `FilteredMapDataSource` observes `user_map_pins` table for automatic map updates when pins change.

## Files Created (2)
- `Packages/PlayaDB/Sources/PlayaDB/Models/UserMapPin.swift` — GRDB record model
- `iBurn/BRCUserMapPoint+PlayaDB.swift` — Conversion helpers + BRCMapPointType string mapping

## Files Modified (7)
- `Packages/PlayaDB/Sources/PlayaDB/PlayaDB.swift` — Added saveUserMapPin, deleteUserMapPin, fetchUserMapPins, observeUserMapPins
- `Packages/PlayaDB/Sources/PlayaDB/PlayaDBImpl.swift` — Schema + implementations
- `iBurn/FilteredMapDataSource.swift` — PlayaDB observation replaces YapCollectionAnnotationDataSource
- `iBurn/UserMapViewAdapter.swift` — PlayaDB writes replace YapDB connections
- `iBurn/MainMapViewController.swift` — findNearest uses async PlayaDB
- `iBurn/BRCDeepLinkRouter.swift` — createMapPin saves to PlayaDB
- `iBurn/UserGuidance.swift` — Async PlayaDB fetch replaces YapDB transaction

## Verification
1. Build succeeds (0 errors)
2. All iBurnTests pass
3. Place/drag/rename/delete pins via PlayaDB
4. Sidebar "find bike/home" navigates to nearest pin
5. Deep link pins saved to PlayaDB

---

# Image Downloader Migration: YapDB → PlayaDB

## Problem
`BRCMediaDownloader` (image instance) used YapDB filtered views (`artImagesViewName`) to enumerate art/camp objects with remote thumbnail URLs but no local files. This was one of the remaining YapDB read paths.

## Solution
Created `ThumbnailImageDownloader` backed by PlayaDB, following the existing `MutantVehicleImageDownloader` pattern. Added `fetchArtImageURLs()` and `fetchCampImageURLs()` to PlayaDB protocol. Removed the `imageDownloader` instance from `BRCAppDelegate`.

## What's Deferred
- **Audio downloader**: PlayaDB `ArtObject` has no `audioUrl` field yet. `_audioDownloader` stays on YapDB.
- **ColorCache**: Legacy UIKit cells still read `thumbnailImageColors` from YapDB metadata. New SwiftUI path (`RowAssetsLoader`) computes colors fresh. ColorCache stays on YapDB until legacy cells are retired.

## Files Created (1)
- `iBurn/ThumbnailImageDownloader.swift` — PlayaDB-backed downloader for art/camp thumbnails

## Files Modified (4)
- `Packages/PlayaDB/Sources/PlayaDB/PlayaDB.swift` — `fetchArtImageURLs()`, `fetchCampImageURLs()`
- `Packages/PlayaDB/Sources/PlayaDB/PlayaDBImpl.swift` — Implementations querying `ArtImage`/`CampImage` tables
- `iBurn/DependencyContainer.swift` — Wire up `ThumbnailImageDownloader`
- `iBurn/BRCAppDelegate.m` — Remove `_imageDownloader` property and background session handler

## Verification
1. Build succeeds (0 errors, 4 pre-existing warnings)
2. All iBurnTests pass
3. Art/camp thumbnails download and display in list views

---

# Map Spatial Queries & Breadcrumbs: YapDB → PlayaDB

## Problem
Two remaining new-code-path dependencies on YapDB:
1. `UserMapViewAdapter.regionDidChangeAnimated` used YapDB R-Tree spatial queries (`BRCDatabaseManager.shared.queryObjects(inMinCoord:maxCoord:)`) to show art/camp/event annotations when zoomed in on the map.
2. `BRCAppDelegate.m` location delegate wrote `BRCBreadcrumbPoint` objects to YapDB on location updates, duplicating work already done by `LocationStorage` (GRDB-backed).

## Solution
1. Replaced YapDB spatial query with `playaDB.fetchObjects(in:)` (already implemented with its own R-Tree). Converts results to `PlayaObjectAnnotation` instead of `DataObjectAnnotation`. Event time filtering uses `fetchUpcomingEvents(within:from:)` to find active/starting-soon events.
2. Removed YapDB breadcrumb writes from AppDelegate — `LocationStorage` already handles breadcrumb tracking via its own `CLLocationManagerDelegate`.

## Also done
- Removed `_audioDownloader` from `BRCAppDelegate.m` — audio tour files are bundled, not downloaded. The `audio_tour_url` field only existed in 2016 data.

## Files Modified (3)
- `iBurn/UserMapViewAdapter.swift` — `regionDidChangeAnimated` uses PlayaDB spatial queries + `PlayaObjectAnnotation`
- `iBurn/PlayaObjectAnnotation.swift` — Added `convenience init?(event: EventObject)` for non-occurrence events
- `iBurn/BRCAppDelegate.m` — Removed breadcrumb YapDB writes, removed `_audioDownloader`

## Remaining YapDB in New Code Path
- `DetailViewModel.syncFavoriteToYapDB/syncNotesToYapDB` — dual-write to keep legacy favorites list in sync. Intentionally kept until legacy UIKit is fully retired.

## Verification
1. Build succeeds (0 errors, 4 pre-existing warnings)
2. All iBurnTests pass
3. Map zoom-in shows art/camp/event annotations via PlayaDB
4. Breadcrumb tracking works via LocationStorage

---

# Detail Page Swiping for New SwiftUI Lists

## Problem
The legacy UIKit list path (`PageViewManager` + `DetailPageViewController`) wraps detail views in a `UIPageViewController`, letting users swipe left/right to navigate to adjacent items in the list. The new SwiftUI hosting controllers pushed detail VCs directly with no swiping support.

## Solution
Created `DetailPagingDataSource` — a reusable class that takes a `[DetailSubject]` snapshot and `PlayaDB`, conforms to `UIPageViewControllerDataSource/Delegate`, and wraps detail views in the existing `DetailPageViewController`.

## Key Design Decisions
- **Snapshot over live data**: Captures `filteredItems` at tap time. The old `PageViewManager` used a live `UITableView` reference which caused occasional crashes when filters changed mid-swipe.
- **`DetailSubject` as common type**: Avoids generics. All 4 object types already have `DetailSubject` cases, and `DetailViewControllerFactory.create(with:playaDB:)` already accepts it.
- **Reuses existing `DetailPageViewController`**: Navigation item forwarding, `DynamicViewController` events all work as-is.
- **Favorites deferred**: Heterogeneous mixed-type list needs different treatment.

## Files Created (1)
- `iBurn/DetailPagingDataSource.swift` — `UIPageViewControllerDataSource/Delegate`, creates `DetailPageViewController` with adjacent-item swiping

## Files Modified (8)
- `iBurn/ListView/ArtListHostingController.swift` — `showDetail` wraps in page VC, stores viewModel + pagingDataSource
- `iBurn/ListView/CampListHostingController.swift` — Same pattern
- `iBurn/ListView/EventListHostingController.swift` — Same pattern (maps `EventObjectOccurrence` → `.eventOccurrence`)
- `iBurn/ListView/MutantVehicleListHostingController.swift` — Same pattern
- `iBurn/ListView/FavoritesListHostingController.swift` — Flattens `allFavoriteItems` → `[DetailSubject]` via `detailSubject` property
- `iBurn/ListView/NearbyListHostingController.swift` — Flattens `sections` → `[DetailSubject]` via `NearbyItem.detailSubject`
- `iBurn/ListView/FavoriteItem.swift` — Added `detailSubject` computed property
- `iBurn/ListView/NearbyItem.swift` — Added `detailSubject` computed property

## Verification
1. Build succeeds (0 errors, 1 pre-existing warning)
2. Tap any item in art/camp/event/MV list → detail view in page VC
3. Swipe left/right → navigates to adjacent items in the filtered list
4. Favorites/Nearby: swiping crosses type boundaries (art → camp → event)
5. Navigation bar title/items update correctly on swipe
