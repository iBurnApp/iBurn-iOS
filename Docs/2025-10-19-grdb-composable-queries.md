# GRDB Migration: Protocol-Based Composable Queries

**Date**: 2025-10-19
**Branch**: grdb-1
**Status**: Foundation Complete

## High-Level Plan

Enhance PlayaDB with protocol-based, composable query extensions to maximize code reuse and type safety. This eliminates query duplication by creating generic extensions that work across all models with shared column types.

## Key Accomplishments

### 1. Column Protocol Hierarchy

Created a hierarchy of column protocols in `ColumnProtocols.swift`:

- **DataObjectColumns**: uid, name, year, description (common to all DataObjects)
- **GeoLocatableColumns**: gpsLatitude, gpsLongitude (for objects with GPS data)
- **WebUrlColumns**: url (for objects with web URLs)
- **ContactEmailColumns**: contactEmail (for objects with contact info)
- **HometownColumns**: hometown (for objects with origin location)
- **LocationStringColumns**: locationString (for human-readable locations)
- **EventOccurrenceColumns**: startTime, endTime (for event timing)

### 2. Model Updates

Updated all PlayaDB models to use public `Columns` enums with protocol conformances:

**ArtObject.Columns** conforms to:
- DataObjectColumns
- GeoLocatableColumns
- WebUrlColumns
- ContactEmailColumns
- HometownColumns
- LocationStringColumns

**CampObject.Columns** conforms to:
- DataObjectColumns
- GeoLocatableColumns
- WebUrlColumns
- ContactEmailColumns
- HometownColumns
- LocationStringColumns

**EventObject.Columns** conforms to:
- DataObjectColumns
- GeoLocatableColumns
- WebUrlColumns

**EventOccurrence.Columns** conforms to:
- EventOccurrenceColumns

**ObjectMetadata.Columns**:
- Updated to public enum pattern for consistency

### 3. Generic Query Extensions

Created composable query extensions that work across all models:

**QueryInterfaceRequest+DataObject.swift**:
- `orderedByName()` - Sort by name (any DataObject)
- `forYear(_:)` - Filter by year (any DataObject)
- `withDescription()` - Has description (any DataObject)
- `descriptionContains(_:)` - Search description (any DataObject)
- `inRegion(_:)` - Geographic filtering (any GeoLocatable)
- `withLocation()` - Has GPS coordinates (any GeoLocatable)
- `orderedByDistance(from:)` - Sort by distance (any GeoLocatable)
- `notExpired(at:)` - Not expired events (any EventOccurrence)
- `happeningNow(at:)` - Currently happening (any EventOccurrence)
- `startingWithin(hours:from:)` - Upcoming events (any EventOccurrence)
- `orderedByStartTime()` - Sort by start time (any EventOccurrence)
- `matching(searchText:)` - Full-text search (any model)
- `onlyFavorites()` - Favorited only (any DataObject)

**QueryInterfaceRequest+Contact.swift**:
- `withUrl()` - Has URL (any WebUrlColumns)
- `withUrl(matching:)` - URL pattern (any WebUrlColumns)
- `withContactEmail()` - Has email (any ContactEmailColumns)
- `withEmailDomain(_:)` - Email domain (any ContactEmailColumns)
- `withHometown()` - Has hometown (any HometownColumns)
- `fromHometown(_:)` - Hometown filter (any HometownColumns)
- `orderedByHometown()` - Sort by hometown (any HometownColumns)
- `withLocationString()` - Has location string (any LocationStringColumns)
- `atLocation(matching:)` - Location pattern (any LocationStringColumns)

## Benefits

### Maximum Code Reuse

**Before** (duplicate code everywhere):
```swift
// Art filtering
artRequest.filter(Column("gps_latitude") >= minLat)
artRequest.filter(Column("gps_latitude") <= maxLat)
artRequest.filter(Column("gps_longitude") >= minLon)
artRequest.filter(Column("gps_longitude") <= maxLon)

// Camp filtering (duplicate!)
campRequest.filter(Column("gps_latitude") >= minLat)
campRequest.filter(Column("gps_latitude") <= maxLat)
campRequest.filter(Column("gps_longitude") >= minLon)
campRequest.filter(Column("gps_longitude") <= maxLon)
```

**After** (single generic extension):
```swift
// Works for Art, Camps, Events!
let nearbyArt = try ArtObject.all().inRegion(region).fetchAll(db)
let nearbyCamps = try CampObject.all().inRegion(region).fetchAll(db)
let nearbyEvents = try EventObject.all().inRegion(region).fetchAll(db)
```

### Type Safety

No string literals - compiler-enforced column names:
```swift
// ✅ Correct - compiles
request.filter(ArtObject.Columns.name == "Temple")

// ❌ Wrong - compiler error!
request.filter(ArtObject.Columns.naem == "Temple")  // typo caught at compile time
```

### Composability

Chain extensions together declaratively:
```swift
let nearbyContactableArt = try ArtObject.all()
    .inRegion(burningManRegion)
    .withContactEmail()
    .withUrl()
    .fromHometown("San Francisco")
    .orderedByDistance(from: userLocation)
    .fetchAll(db)

// Same filters work for camps!
let nearbyContactableCamps = try CampObject.all()
    .inRegion(burningManRegion)
    .withContactEmail()
    .withUrl()
    .fromHometown("San Francisco")
    .orderedByDistance(from: userLocation)
    .fetchAll(db)
```

### Generic Functions

Write functions that work for multiple types:
```swift
func objectsWithWebsite<T>() async throws -> [T]
    where T: FetchableRecord,
          T.Columns: DataObjectColumns & WebUrlColumns
{
    try await dbQueue.read { db in
        try T.all()
            .withUrl()
            .orderedByName()
            .fetchAll(db)
    }
}

// Works for Art, Camps, Events!
let artWithWebsites: [ArtObject] = try await objectsWithWebsite()
let campsWithWebsites: [CampObject] = try await objectsWithWebsite()
let eventsWithWebsites: [EventObject] = try await objectsWithWebsite()
```

## File Structure

```
Packages/PlayaDB/Sources/PlayaDB/
├── Protocols/
│   └── ColumnProtocols.swift                      # All column protocols
├── Models/
│   ├── ArtObject.swift                            # 7 protocol conformances
│   ├── CampObject.swift                           # 7 protocol conformances
│   ├── EventObject.swift                          # 4 protocol conformances
│   ├── EventObjectOccurrence.swift                # Composite type
│   └── ObjectMetadata.swift                       # Public Columns enum
├── QueryExtensions/
│   ├── QueryInterfaceRequest+DataObject.swift     # Core extensions
│   └── QueryInterfaceRequest+Contact.swift        # Contact info extensions
├── PlayaDB.swift                                  # Protocol interface
└── PlayaDBImpl.swift                              # Implementation
```

## Next Steps

### Phase 2: Filter Structs & Query Methods (Next Session)

1. **Create Filter Structs**:
   - `ArtFilter` - onlyWithEvents, onlyFavorites, inRegion, searchText
   - `CampFilter` - onlyFavorites, inRegion, searchText
   - `FavoritesFilter` - objectType, includeExpiredEvents, searchText
   - `EventFilter` - onlyFavorites, includeExpired, searchText

2. **Add PlayaDB Query Methods**:
   - `fetchArt(filter: ArtFilter)`
   - `observeArt(filter: ArtFilter)`
   - `fetchCamps(filter: CampFilter)`
   - `observeCamps(filter: CampFilter)`
   - `fetchFavorites(filter: FavoritesFilter)`
   - `observeFavorites(filter: FavoritesFilter)`

3. **Create Request Builders**:
   - `artRequest(filter: ArtFilter)` - compose filters into GRDB request
   - `campRequest(filter: CampFilter)`
   - `eventRequest(filter: EventFilter)`

4. **Generic Observation Helper**:
   - `observe<T>(_ request: QueryInterfaceRequest<T>)`

### Phase 3: SwiftUI Migration (Future)

1. **Service Layer**:
   - `ObjectQueryService` protocol
   - Concrete implementations using filter-based queries

2. **SwiftUI ViewModels**:
   - `ObjectListState<T, Service>` - generic list state
   - Feature-specific states using composition

3. **SwiftUI Views**:
   - `ArtListView`, `FavoritesListView`, etc.
   - Leverage reactive `observe` methods

## Architecture Validation

This foundation enables:
- ✅ **Database-level filtering** - SQL does the work, not Swift
- ✅ **Type safety** - Compiler-checked column names
- ✅ **Code reuse** - Generic extensions work across models
- ✅ **Composability** - Chain filters declaratively
- ✅ **Testability** - Easy to test individual extensions
- ✅ **Maintainability** - Single source of truth for query logic

## Example: Complete Query

```swift
// Complex query built from simple, composable pieces
let result = try ArtObject.all()
    .withLocation()              // Has GPS coordinates (GeoLocatableColumns)
    .inRegion(userRegion)        // Near user (GeoLocatableColumns)
    .withUrl()                   // Has website (WebUrlColumns)
    .withContactEmail()          // Has email (ContactEmailColumns)
    .fromHometown("Oakland")     // From Oakland (HometownColumns)
    .onlyFavorites()             // User favorited (DataObject)
    .matching(searchText: "LED") // Text search (FTS5)
    .orderedByName()             // Alphabetical (DataObjectColumns)
    .fetchAll(db)

// Generated SQL (optimized by SQLite):
// SELECT art_objects.*
// FROM art_objects
// INNER JOIN object_metadata ON ...
// WHERE gps_latitude IS NOT NULL
//   AND gps_latitude >= ? AND gps_latitude <= ?
//   AND gps_longitude >= ? AND gps_longitude <= ?
//   AND url IS NOT NULL
//   AND contact_email IS NOT NULL
//   AND hometown LIKE '%Oakland%'
//   AND art_objects.rowid IN (SELECT rowid FROM art_objects_fts WHERE ...)
// ORDER BY name ASC
```

This is production-grade, maintainable, and follows Swift best practices!
