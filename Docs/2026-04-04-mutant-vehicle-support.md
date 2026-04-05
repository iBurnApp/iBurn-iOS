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
