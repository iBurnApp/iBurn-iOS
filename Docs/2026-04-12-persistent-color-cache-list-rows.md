# Persistent Color Cache + Fully-Inflated List Rows

## Status: Implementation Complete (Build Passing, 0 errors, 0 warnings)

## Context
Previously, list views ran two separate observations (items + favorites) and computed thumbnail colors async in RowAssetsLoader. This change:

1. **Fully-inflated row objects from the data layer** — each list row comes from the DB with `isFavorite` and `thumbnailColors` already attached, in a single read transaction.
2. **List rows**: Only Art and MV apply thumbnail-derived colors. Camps/Events use default theme.
3. **Detail views**: All types use thumbnail colors.
4. **Persistent color cache**: GRDB `thumbnail_colors` table with Codable model.
5. **Background prefetch**: Compute missing colors at launch after thumbnail downloads.
6. **Thumbnail validation**: Re-download corrupt/empty files.

## Core Design: `ListRow<T>`

A fully-inflated wrapper returned from the data layer. The observation JOINs object + metadata + colors in one read transaction. Includes **full** `ObjectMetadata` (not just isFavorite) since we're doing the JOIN anyway:

```swift
// In PlayaDB package
public struct ListRow<T> {
    public let object: T
    public let metadata: ObjectMetadata?       // full metadata: favorites, notes, viewed dates, etc.
    public let thumbnailColors: ThumbnailColors?
    
    public var isFavorite: Bool { metadata?.isFavorite ?? false }
}
```

The observation callback delivers `[ListRow<ArtObject>]` (not `[ArtObject]` + separate favorites set). The ViewModel stores these directly. No merging.

```
┌────────────────────────────────────────────────────────┐
│              Single GRDB Read Transaction               │
│                                                        │
│  SELECT ao.*, om.*, tc.*                               │
│  FROM art_objects ao                                   │
│  LEFT JOIN object_metadata om ON ...                   │
│  LEFT JOIN thumbnail_colors tc ON ...                  │
│                                                        │
│  Result: [ListRow<ArtObject>]                          │
│    ├── .object: ArtObject (name, artist, location...)  │
│    ├── .metadata: ObjectMetadata? (favorite, notes...) │
│    └── .thumbnailColors: ThumbnailColors?              │
└────────────────────────────────────────────────────────┘
                         │
                         ▼
              ObjectListViewModel
              @Published items: [ListRow<Object>]
                         │
                         ▼
              ForEach(items) { row in
                ObjectRowView(
                  object: row.object,
                  isFavorite: row.isFavorite,
                  thumbnailColors: row.thumbnailColors,
                  ...
                )
              }
```

## Files Changed

### PlayaDB Package

| File | Action | Description |
|------|--------|-------------|
| `Models/ThumbnailColors.swift` | **NEW** | Codable GRDB model for cached colors (16 REAL columns) |
| `Models/ListRow.swift` | **NEW** | `ListRow<T>` — fully-inflated row with object + isFavorite + colors |
| `PlayaDB.swift` | MODIFY | Replace observe methods to return `[ListRow<T>]`; add ThumbnailColors CRUD |
| `PlayaDBImpl.swift` | MODIFY | `thumbnail_colors` table; observation impl with JOIN; CRUD |

### App Target

| File | Action | Description |
|------|--------|-------------|
| `ColorPrefetcher.swift` | **NEW** | Background prefetch into `thumbnail_colors` table |
| `ListView/DisplayableObject.swift` | MODIFY | Add `supportsColorTheming` (true for Art/MV) |
| `ListView/ObjectListDataProvider.swift` | MODIFY | `observeObjects` returns `AsyncStream<[ListRow<Object>]>` |
| `ListView/ArtDataProvider.swift` | MODIFY | Use new observation returning ListRow |
| `ListView/CampDataProvider.swift` | MODIFY | Use new observation returning ListRow |
| `ListView/MutantVehicleDataProvider.swift` | MODIFY | Use new observation returning ListRow |
| `ListView/EventDataProvider.swift` | MODIFY | Use new observation returning ListRow |
| `ListView/ObjectListViewModel.swift` | MODIFY | Store `[ListRow<Object>]`; remove separate favorites observation |
| `ListView/ObjectRowView.swift` | MODIFY | Accept `thumbnailColors`, gate on `supportsColorTheming` |
| `ListView/ArtListView.swift` | MODIFY | Pass row data from ListRow |
| `ListView/CampListView.swift` | MODIFY | Pass row data from ListRow |
| `ListView/MutantVehicleListView.swift` | MODIFY | Pass row data from ListRow |
| `ListView/EventListView.swift` | MODIFY | Pass row data from ListRow |
| `ListView/RowAssetsLoader.swift` | MODIFY | Read/write `thumbnail_colors` for detail views |
| `ThumbnailImageDownloader.swift` | MODIFY | Awaitable return, corrupt file validation |
| `MutantVehicleImageDownloader.swift` | MODIFY | Awaitable return, corrupt file validation |
| `DependencyContainer.swift` | MODIFY | Download → prefetch sequencing |
| Other views using ObjectRowView | MODIFY | Pass thumbnailColors param (FavoritesView, NearbyView, etc.) |

## Detailed Plan

### 1. NEW: `Packages/PlayaDB/.../Models/ThumbnailColors.swift`

```swift
public struct ThumbnailColors: Codable, FetchableRecord, MutablePersistableRecord, Equatable {
    public static let databaseTableName = "thumbnail_colors"
    
    public enum Columns: String, CodingKey, ColumnExpression {
        case objectId = "object_id"
        case bgRed = "bg_red", bgGreen = "bg_green", bgBlue = "bg_blue", bgAlpha = "bg_alpha"
        case primaryRed = "primary_red", primaryGreen = "primary_green"
        case primaryBlue = "primary_blue", primaryAlpha = "primary_alpha"
        case secondaryRed = "secondary_red", secondaryGreen = "secondary_green"
        case secondaryBlue = "secondary_blue", secondaryAlpha = "secondary_alpha"
        case detailRed = "detail_red", detailGreen = "detail_green"
        case detailBlue = "detail_blue", detailAlpha = "detail_alpha"
    }
    private typealias CodingKeys = Columns
    
    public var objectId: String  // PRIMARY KEY
    // 4 colors × 4 RGBA components = 16 doubles
    public var bgRed: Double, bgGreen: Double, bgBlue: Double, bgAlpha: Double
    public var primaryRed: Double, primaryGreen: Double, primaryBlue: Double, primaryAlpha: Double
    public var secondaryRed: Double, secondaryGreen: Double, secondaryBlue: Double, secondaryAlpha: Double
    public var detailRed: Double, detailGreen: Double, detailBlue: Double, detailAlpha: Double
}
```

### 2. NEW: `Packages/PlayaDB/.../Models/ListRow.swift`

```swift
/// Fully-inflated row for list views. Bundles the data object with all metadata
/// needed for rendering, fetched in a single read transaction.
public struct ListRow<T> {
    public let object: T
    public let metadata: ObjectMetadata?       // full metadata from object_metadata table
    public let thumbnailColors: ThumbnailColors?
    
    /// Convenience: whether this object is favorited
    public var isFavorite: Bool { metadata?.isFavorite ?? false }
    
    public init(object: T, metadata: ObjectMetadata?, thumbnailColors: ThumbnailColors?) {
        self.object = object
        self.metadata = metadata
        self.thumbnailColors = thumbnailColors
    }
}
```

### 3. MODIFY: `PlayaDBImpl.swift` — Table + Observation

**Table creation** in `setupDatabase()`:
```sql
CREATE TABLE IF NOT EXISTS thumbnail_colors (
    object_id TEXT PRIMARY KEY,
    bg_red REAL NOT NULL, bg_green REAL NOT NULL, bg_blue REAL NOT NULL, bg_alpha REAL NOT NULL,
    primary_red REAL NOT NULL, primary_green REAL NOT NULL, primary_blue REAL NOT NULL, primary_alpha REAL NOT NULL,
    secondary_red REAL NOT NULL, secondary_green REAL NOT NULL, secondary_blue REAL NOT NULL, secondary_alpha REAL NOT NULL,
    detail_red REAL NOT NULL, detail_green REAL NOT NULL, detail_blue REAL NOT NULL, detail_alpha REAL NOT NULL
)
```

**Annotated observation** (replaces current `observe()` helper). Single read transaction fetches objects, then batch-fetches favorites + colors for those object IDs:

```swift
private func observeListRows<T: FetchableRecord>(
    type: DataObjectType,
    value: @escaping @Sendable (Database) throws -> [T],
    ids: @escaping ([T]) -> [String],
    onChange: @escaping ([ListRow<T>]) -> Void,
    onError: @escaping (Error) -> Void
) -> PlayaDBObservationToken {
    let observation = ValueObservation.tracking { db -> [ListRow<T>] in
        let objects = try value(db)
        let objectIDs = ids(objects)
        guard !objectIDs.isEmpty else { return [] }
        
        // Batch fetch full metadata in same transaction
        let allMeta = try ObjectMetadata
            .filter(ObjectMetadata.Columns.objectType == type.rawValue)
            .filter(objectIDs.contains(ObjectMetadata.Columns.objectId))
            .fetchAll(db)
        let metaByID = Dictionary(uniqueKeysWithValues: allMeta.map { ($0.objectId, $0) })
        
        // Batch fetch colors in same transaction
        let allColors = try ThumbnailColors
            .filter(objectIDs.contains(ThumbnailColors.Columns.objectId))
            .fetchAll(db)
        let colorsByID = Dictionary(uniqueKeysWithValues: allColors.map { ($0.objectId, $0) })
        
        // Build fully-inflated rows
        return objects.map { obj in
            let uid = ids([obj]).first ?? ""
            return ListRow(
                object: obj,
                metadata: metaByID[uid],
                thumbnailColors: colorsByID[uid]
            )
        }
    }
    let cancellable = observation.start(in: dbQueue, onError: onError) { [weak self] rows in
        let identifiers = ids(rows.map(\.object))
        if !identifiers.isEmpty {
            Task { try? await self?.ensureMetadata(for: type, ids: identifiers) }
        }
        onChange(rows)
    }
    return PlayaDBObservationToken(cancellable)
}
```

**Concrete methods**: `observeArt(filter:onChange:onError:)` now returns `[ListRow<ArtObject>]` via callback. Same for camps, MV, events.

**ThumbnailColors CRUD**:
```swift
func saveThumbnailColors(_ colors: ThumbnailColors) async throws
func saveThumbnailColorsBatch(_ batch: [ThumbnailColors]) async throws  // single transaction
func fetchThumbnailColors(objectId: String) async throws -> ThumbnailColors?
```

### 4. MODIFY: `PlayaDB.swift` Protocol

Update observation signatures to return `[ListRow<T>]` with full metadata:
```swift
func observeArt(filter: ArtFilter, onChange: @escaping ([ListRow<ArtObject>]) -> Void, onError: @escaping (Error) -> Void) -> PlayaDBObservationToken
func observeCamps(filter: CampFilter, onChange: @escaping ([ListRow<CampObject>]) -> Void, ...) -> PlayaDBObservationToken
func observeMutantVehicles(filter: MutantVehicleFilter, onChange: @escaping ([ListRow<MutantVehicleObject>]) -> Void, ...) -> PlayaDBObservationToken
func observeEvents(filter: EventFilter, onChange: @escaping ([ListRow<EventObjectOccurrence>]) -> Void, ...) -> PlayaDBObservationToken

// ThumbnailColors CRUD
func saveThumbnailColors(_ colors: ThumbnailColors) async throws
func saveThumbnailColorsBatch(_ batch: [ThumbnailColors]) async throws
func fetchThumbnailColors(objectId: String) async throws -> ThumbnailColors?
```

Each ListRow includes full `ObjectMetadata?` — not just isFavorite. This gives views access to favorites, notes, viewed dates, and any future metadata fields without additional queries.

### 5. MODIFY: `DisplayableObject.swift`

Add `supportsColorTheming`:
```swift
protocol DisplayableObject {
    // ... existing ...
    static var supportsColorTheming: Bool { get }
}
extension DisplayableObject {
    static var supportsColorTheming: Bool { false }
}
extension ArtObject: DisplayableObject { static var supportsColorTheming: Bool { true } }
extension MutantVehicleObject: DisplayableObject { static var supportsColorTheming: Bool { true } }
// Camp, Event, EventOccurrence inherit false
```

### 6. MODIFY: `ObjectListDataProvider.swift`

```swift
protocol ObjectListDataProvider<Object, Filter> {
    associatedtype Object
    associatedtype Filter
    
    func observeObjects(filter: Filter) -> AsyncStream<[ListRow<Object>]>  // returns ListRow
    func toggleFavorite(_ object: Object) async throws
    func distanceAttributedString(from: CLLocation?, to: Object) -> AttributedString?
    // Remove: func isFavorite(_ object: Object) async throws -> Bool  (now on ListRow)
}
```

### 7. MODIFY: Concrete Data Providers

Each provider's `observeObjects` wraps the new PlayaDB observation:
```swift
func observeObjects(filter: ArtFilter) -> AsyncStream<[ListRow<ArtObject>]> {
    AsyncStream { continuation in
        let token = playaDB.observeArt(filter: filter) { rows in
            continuation.yield(rows)  // already [ListRow<ArtObject>]
        } onError: { error in ... }
        continuation.onTermination = { _ in token.cancel() }
    }
}
```

### 8. MODIFY: `ObjectListViewModel.swift`

Store fully-inflated rows. Remove separate favorites observation:

```swift
@Published var items: [ListRow<Object>] = []
// REMOVE: @Published private(set) var favoriteIDs: Set<String> = []

func isFavorite(_ object: Object) -> Bool {
    items.first(where: { $0.object.uid == object.uid })?.isFavorite ?? false
}

var filteredItems: [ListRow<Object>] {
    guard !searchText.isEmpty else { return items }
    let q = searchText.lowercased()
    return items.filter { matchesSearch($0.object, q) }
}

func toggleFavorite(_ row: ListRow<Object>) async {
    // Optimistic update — flip isFavorite in the metadata
    if let idx = items.firstIndex(where: { $0.object.uid == row.object.uid }) {
        var updatedMeta = row.metadata ?? ObjectMetadata.forArt(id: row.object.uid)
        updatedMeta.isFavorite = !row.isFavorite
        items[idx] = ListRow(object: row.object, metadata: updatedMeta, thumbnailColors: row.thumbnailColors)
    }
    do {
        try await dataProvider.toggleFavorite(row.object)
        // Observation re-fires with correct state from DB
    } catch {
        // Revert on failure
        if let idx = items.firstIndex(where: { $0.object.uid == row.object.uid }) {
            items[idx] = row
        }
    }
}

// REMOVE: startObservingFavorites() — no longer needed
// Single observation in startObserving():
private func startObserving() {
    observationTask = Task { [weak self] in
        guard let self else { return }
        for await rows in dataProvider.observeObjects(filter: effectiveFilter) {
            await MainActor.run {
                self.items = rows
                if !rows.isEmpty { self.isLoading = false }
            }
        }
    }
}
```

### 9. MODIFY: `ObjectRowView.swift`

Accept optional `ThumbnailColors?`. Gate on `Object.supportsColorTheming`:

```swift
struct ObjectRowView<Object: DisplayableObject, Actions: View>: View {
    let object: Object
    let subtitle: AttributedString?
    let rightSubtitle: String?
    let isFavorite: Bool
    let thumbnailColors: ThumbnailColors?  // NEW
    let onFavoriteTap: () -> Void
    @ViewBuilder let actions: (RowAssetsLoader) -> Actions
    @StateObject private var assets: RowAssetsLoader
    @Environment(\.themeColors) var themeColors

    var body: some View {
        let colors: ImageColors = {
            if Object.supportsColorTheming, let tc = thumbnailColors {
                return tc.imageColors  // ThumbnailColors → ImageColors conversion
            }
            return themeColors
        }()
        // ... rest uses `colors` for text + background
    }
    
    private var listRowBackground: some View {
        ZStack {
            themeColors.backgroundColor
            if Object.supportsColorTheming, let tc = thumbnailColors {
                Color(tc.backgroundColor)  // convenience computed property
                    .transition(.opacity)
            }
        }
    }
}
```

RowAssetsLoader remains for thumbnail/audio loading. It no longer handles colors for list views.

### 10. MODIFY: All List Views

Pass row data from `ListRow`. Example for ArtListView:
```swift
ForEach(viewModel.filteredItems, id: \.object.uid) { row in
    ObjectRowView(
        object: row.object,
        subtitle: viewModel.distanceAttributedString(for: row.object),
        rightSubtitle: row.object.artist,
        isFavorite: row.isFavorite,
        thumbnailColors: row.thumbnailColors,
        onFavoriteTap: { Task { await viewModel.toggleFavorite(row) } }
    ) { assets in ... }
}
```

Same pattern for CampListView, MutantVehicleListView, EventListView, FavoritesView, NearbyView, RecentlyViewedView, GlobalSearchView, AI views.

### 11. MODIFY: `RowAssetsLoader.swift`

For **detail views** (which use colors for ALL types):
- Read from `thumbnail_colors` table synchronously at init (via PlayaDB)
- Write extracted colors back to `thumbnail_colors` table after async extraction
- Keep existing NSCache as L1 cache
- Make colorsCache internal for ColorPrefetcher access

### 12. NEW: `iBurn/ColorPrefetcher.swift`

Background prefetch into `thumbnail_colors` table. Runs after thumbnail downloads complete:

```swift
enum ColorPrefetcher {
    static func prefetchMissingColors(playaDB: PlayaDB) async {
        // 1. Get all UIDs that have local thumbnails (art + camp + MV)
        // 2. Fetch existing thumbnail_colors entries
        // 3. Compute colors for missing entries
        // 4. Batch write to DB in single transaction (one observation re-fire)
    }
}
```

### 13. MODIFY: Downloaders

Return awaitable `Task<Set<String>, Never>`. Add corrupt file validation:
```swift
@discardableResult
func downloadUncachedImages() -> Task<Set<String>, Never> {
    // Validate existing files: check size > 0, re-download if invalid
    // Return set of newly downloaded UIDs
}
```

### 14. MODIFY: `DependencyContainer.swift`

Sequence: downloads → prefetch:
```swift
let mvTask = mvImageDownloader.downloadUncachedImages()
let thumbTask = thumbnailImageDownloader.downloadUncachedImages()
Task.detached(priority: .utility) { [playaDB] in
    _ = await mvTask.value
    _ = await thumbTask.value
    await ColorPrefetcher.prefetchMissingColors(playaDB: playaDB)
}
```

### 15. Conversion Helpers (in app target, not PlayaDB)

`ThumbnailColors` stores raw doubles. The app converts to UIColor/SwiftUI Color:

```swift
// Extension in app target (ThumbnailColors is in PlayaDB, UIColor is UIKit)
extension ThumbnailColors {
    var backgroundColor: UIColor { UIColor(red: bgRed, green: bgGreen, blue: bgBlue, alpha: bgAlpha) }
    var primaryColor: UIColor { ... }
    var secondaryColor: UIColor { ... }
    var detailColor: UIColor { ... }
    
    var imageColors: ImageColors {
        ImageColors(
            backgroundColor: Color(backgroundColor),
            primaryColor: Color(primaryColor),
            secondaryColor: Color(secondaryColor),
            detailColor: Color(detailColor)
        )
    }
    
    init(objectId: String, brcColors: BRCImageColors) {
        // Extract RGBA components from UIColors
    }
}
```

## Implementation Order

1. `ThumbnailColors` model + table creation in PlayaDB
2. `ListRow<T>` struct in PlayaDB
3. ThumbnailColors CRUD in PlayaDB protocol + impl
4. Annotated observation in PlayaDB (returns `[ListRow<T>]`)
5. `DisplayableObject.supportsColorTheming`
6. `ObjectListDataProvider` — update to return `[ListRow<Object>]`
7. Concrete data providers — use new observations
8. `ObjectListViewModel` — single observation, store `[ListRow<Object>]`, remove favorites obs
9. `ObjectRowView` — accept thumbnailColors, gate on supportsColorTheming
10. All list views — pass row data from ListRow
11. `RowAssetsLoader` — read/write thumbnail_colors for detail views
12. Conversion helpers (ThumbnailColors → UIColor/ImageColors)
13. Downloaders — awaitable + validation
14. `ColorPrefetcher` — background batch prefetch
15. `DependencyContainer` — wire up

## Step 10 Completion: All List Views Updated to Use `ListRow<T>`

All list views and their hosting controllers have been updated to use `ListRow<T>` from the data layer.

### Files Modified

**Type-erased item enums updated to wrap `ListRow<T>`:**
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/NearbyItem.swift` — `NearbyItem` wraps `ListRow<ArtObject>`, `ListRow<CampObject>`, `ListRow<EventObjectOccurrence>`
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/FavoriteItem.swift` — `FavoriteItem` wraps `ListRow<T>` for all four types, added `isFavorite` and `thumbnailColors` accessors

**View models updated to store `[ListRow<T>]`:**
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/NearbyViewModel.swift` — `toggleFavorite` extracts `.object`, `allAnnotations` extracts `.object`, `distanceString` extracts `.object`
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/FavoritesViewModel.swift` — stored arrays changed to `[ListRow<T>]`, filtering functions updated to access `.object`, `toggleFavorite`/`distanceAttributedString`/`allAnnotations` extract `.object`, `resolveHosts` uses `.map(\.object)`

**List views updated (ForEach + ObjectRowView + callbacks):**
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/ArtListView.swift` — ForEach uses `\.object.uid`, row fields access `row.object.*`, `showMap` maps to `.object`
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/CampListView.swift` — same pattern
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/EventListView.swift` — `eventRow` accepts `ListRow<EventObjectOccurrence>`, `showMap` maps to `.object`
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/MutantVehicleListView.swift` — same pattern
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/NearbyView.swift` — all three cases extract `.object` for ObjectRowView and callbacks, use `.isFavorite`
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/FavoritesView.swift` — all four cases extract `.object` for ObjectRowView and callbacks, use `.isFavorite`

**Hosting controllers updated:**
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/ArtListHostingController.swift` — `showDetail` maps `filteredItems` via `.object`
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/CampListHostingController.swift` — same
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/EventListHostingController.swift` — same
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/MutantVehicleListHostingController.swift` — same
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/FavoritesListHostingController.swift` — wraps bare objects in `ListRow(object:, metadata: nil, thumbnailColors: nil)` when constructing FavoriteItem for navigation

**Not changed (no observation-based `ListRow` usage):**
- `RecentlyViewedItem` / `RecentlyViewedViewModel` / `RecentlyViewedView` — uses custom fetch, not observation
- `GlobalSearchHostingController` / `SearchResultItem` — uses search API, not observation
- `ObjectListViewModel` / `EventListViewModel` — already updated in prior step

### Build Status
Build succeeds with 0 errors, 4 pre-existing warnings (Sendable, async alternatives, MainActor isolation).

## DetailPageItem Pass-Through from List Hosting Controllers

Updated all 6 list hosting controllers to pass pre-loaded `metadata` and `thumbnailColors` from `ListRow` data through to the detail view via `DetailPageItem`, instead of using bare `DetailSubject` arrays.

### Changes

**Hosting controllers updated to build `[DetailPageItem]` instead of `[DetailSubject]`:**
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/ArtListHostingController.swift` — `showDetail` builds `DetailPageItem(subject: .art(row.object), metadata: row.metadata, thumbnailColors: row.thumbnailColors)`
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/CampListHostingController.swift` — same pattern with `.camp`
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/MutantVehicleListHostingController.swift` — same with `.mutantVehicle`
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/EventListHostingController.swift` — same with `.eventOccurrence`
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/FavoritesListHostingController.swift` — uses `allFavoriteItems.map { $0.detailPageItem }`
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/NearbyListHostingController.swift` — uses `allItems.map(\.detailPageItem)`, index lookup uses `detailSubject.uid`

**Enum types extended with `metadata` and `detailPageItem` computed properties:**
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/FavoriteItem.swift` — added `metadata: ObjectMetadata?` and `detailPageItem: DetailPageItem`
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/NearbyItem.swift` — added `metadata: ObjectMetadata?` and `detailPageItem: DetailPageItem`

### Result
Detail views now receive pre-loaded metadata and thumbnail colors from the list data, avoiding redundant DB fetches when navigating from a list to detail. Build succeeds with 0 errors.

## Verification
1. Build and run, scroll Art list — rows show thumbnail colors
2. MV list — colored rows
3. Camp/Event lists — default/plain theme
4. Tap Camp → detail view still shows thumbnail colors
5. Kill + restart → colors load immediately from DB (no flicker)
6. Toggle a favorite in list → row updates instantly (optimistic), persists correctly
7. Only one GRDB observation per list (verify in debugger/logs)
8. ColorPrefetcher console log shows batch computation at launch
