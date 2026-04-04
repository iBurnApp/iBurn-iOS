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
