# Add Host Name and Location to Event List Cells

## Problem Statement

When all list row types were unified into `ObjectRowView` (commit `78a1c0c`), the event-specific "host name + location address" row was dropped. The old `EventRowView` had a dedicated Row 2 between the title and thumbnail showing `[Host Name] ... [Location Address]`. Additionally, the DetailViewModel was redundantly re-fetching the host camp/art object that had already been loaded by the list query.

## Solution Overview

1. **GRDB JOIN queries** - Define `EventObject.hostedCamp` and `EventObject.locatedArt` GRDB associations, resolve host data in a single SQL JOIN
2. **`PlaceDataObject` protocol** - Sub-protocol of `DataObject` providing `address` for camps and art, with type-specific fallback chains
3. **Pre-loaded host on `EventObjectOccurrence`** - Store the full host object (`any PlaceDataObject`) from the JOIN, computed `hostName`/`hostAddress` via protocol dispatch
4. **Display host row in `ObjectRowView`** - Optional `hostName`/`hostAddress` parameters with embargo gating
5. **Dead code cleanup** - Removed `ResolvedEventHost` struct and all async `resolvedHosts` machinery from 5 view models

## Architecture

### PlaceDataObject Protocol

**File:** `Packages/PlayaDB/Sources/PlayaDB/DataObject.swift`

```swift
public protocol PlaceDataObject: DataObject {
    var address: String? { get }
}
```

- `CampObject`: `address` = `locationString ?? intersection`
- `ArtObject`: `address` = `locationString ?? timeBasedAddress`

### EventObjectOccurrence Host

**File:** `Packages/PlayaDB/Sources/PlayaDB/Models/EventObjectOccurrence.swift`

```swift
public let host: (any PlaceDataObject)?
public var hostName: String? { host?.name }
public var hostAddress: String? { host?.address }
```

Populated by `EventOccurrenceJoinedRow.toEventObjectOccurrence()` from GRDB JOIN results.

### GRDB Associations

**File:** `Packages/PlayaDB/Sources/PlayaDB/Models/EventObject.swift`

```swift
static let hostedCamp = belongsTo(CampObject.self, key: "hostedCamp", ...)
static let locatedArt = belongsTo(ArtObject.self, key: "locatedArt", ...)
```

Single JOIN query replaces 4 batch queries per event observation.

### DetailViewModel Pre-loading

**File:** `iBurn/Detail/ViewModels/DetailViewModel.swift`

The `.eventOccurrence` case uses the pre-loaded host from JOIN, falling back to async fetch only if not available. Common name/description/address use `PlaceDataObject` protocol dispatch; only `DetailSubject` creation and hosted events query require type-specific branches.

## Embargo Handling

Host address is location data and gated by `BRCEmbargo.allowEmbargoedData()` at each view call site:
```swift
hostAddress: BRCEmbargo.allowEmbargoedData() ? event.object.hostAddress : nil
```

## Files Modified

### PlayaDB Package
- `Packages/PlayaDB/Sources/PlayaDB/DataObject.swift` — `PlaceDataObject` protocol
- `Packages/PlayaDB/Sources/PlayaDB/Models/CampObject.swift` — `PlaceDataObject` conformance
- `Packages/PlayaDB/Sources/PlayaDB/Models/ArtObject.swift` — `PlaceDataObject` conformance
- `Packages/PlayaDB/Sources/PlayaDB/Models/EventObject.swift` — GRDB associations
- `Packages/PlayaDB/Sources/PlayaDB/Models/EventObjectOccurrence.swift` — `host: (any PlaceDataObject)?`, `EventOccurrenceJoinedRow`
- `Packages/PlayaDB/Sources/PlayaDB/PlayaDBImpl.swift` — JOIN queries

### UI Layer
- `iBurn/ListView/ObjectRowView.swift` — `hostName`/`hostAddress` params + conditional row
- `iBurn/ListView/NearbyView.swift` — pass host data
- `iBurn/ListView/EventListView.swift` — pass host data
- `iBurn/ListView/FavoritesView.swift` — pass host data
- `iBurn/ListView/GlobalSearchView.swift` — pass host data
- `iBurn/ListView/RecentlyViewedView.swift` — pass host data
- `iBurn/Detail/ViewModels/DetailViewModel.swift` — use pre-loaded host

### Dead Code Removed
- `ResolvedEventHost` struct and all `resolvedHosts`/`resolveHosts()` from 5 view models

## Performance Impact

Before: 4 batch queries per event observation + N+1 async queries in view models + 1 fetch per event detail
After: 1 SQL JOIN query, zero async resolution, zero redundant fetches in detail view

## Tests

Added 18 tests across 3 files in `Packages/PlayaDB/Tests/PlayaDBTests/`:

- `PlaceDataObjectTests.swift` (new, 7 tests) — `CampObject.address` and `ArtObject.address` fallback chains, including `timeBasedAddress` formatting.
- `EventObjectOccurrenceTests.swift` (extended, +6 tests) — `EventObjectOccurrence.host`/`hostName`/`hostAddress` delegation; `EventOccurrenceJoinedRow.toEventObjectOccurrence()` precedence (camp wins over art, art fallback, nil-safe).
- `EventHostPreloadingTests.swift` (new, 5 tests) — Integration tests through the public `fetchEvents()` and `fetchEvents(hostedByCampUID:)` APIs covering camp host pre-loading, art host pre-loading, missing-host safety, and batch resolution across multiple hosts.

Style: tests use `@testable import PlayaDB` (no `as!` casts) and `try XCTUnwrap(...)` (no `!` force-unwraps).

Also fixed pre-existing `ListRow<T>` wrapper breakage in `FilterObservationTests.swift` (4 sites) that was preventing the test target from compiling. Full suite: 128 tests pass.
