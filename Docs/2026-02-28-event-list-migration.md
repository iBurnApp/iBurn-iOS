# Event List Migration to SwiftUI + PlayaDB (2026-02-28)

## Session Summary

Resumed work on the `playadb-migration` branch. Started by verifying the build was clean (0 errors, 0 warnings, 37 iBurnTests pass, 77 PlayaDB SPM tests pass). Noted that the `PlayaKitTests` scheme is broken (references a target that no longer exists — dangling scheme). Then implemented the full SwiftUI Event list migration as the next vertical slice of the PlayaDB migration.

## High-Level Plan

- **Problem Statement**: The Events tab still uses legacy UIKit `EventListViewController` backed by YapDatabase. Art and Camp lists were already migrated to SwiftUI + PlayaDB behind the `useSwiftUILists` feature flag.
- **Solution Overview**: Build a SwiftUI EventListView following the established Art/Camp pattern, with event-specific features: day picker, hourly grouping, time-based status indicators, event type filtering.
- **Key Changes**: 8 new files, 6 modified files (see below).

## Technical Details

### New Files Created

1. **`iBurn/ListView/EventDataProvider.swift`** — `ObjectListDataProvider` for `EventObjectOccurrence`/`EventFilter`. Wraps PlayaDB observation in AsyncStream. Favorites stored per-event (not per-occurrence).

2. **`iBurn/ListView/EventTypeInfo.swift`** — Pure Swift mapping of event type codes to display names and emoji. Verified codes from 2025 bundled data: `work`, `prty`, `food`, `arts`, `tea`, `adlt`, `kid`, `othr`.

3. **`iBurn/ListView/EventListViewModel.swift`** — Custom `@MainActor ObservableObject` (not generic `ObjectListViewModel` — events need day selection, hourly grouping, 60s refresh timer). Key features:
   - `selectedDay: Date` drives day-scoped observation restart
   - `now: Date` refreshed every 60s for status indicators
   - `groupedItems` computed property groups by hour with "10 AM", "11 AM" headers
   - Dual observation pattern (items + favorites) matching Art/Camp
   - `effectiveFilter()` merges selectedDay into EventFilter as startDate/endDate
   - Filter persistence excludes startDate/endDate (those come from selectedDay)
   - Favorites tracked by event UID (not occurrence UID)

4. **`iBurn/ListView/EventDayPickerView.swift`** — Horizontal ScrollView of day buttons with auto-scroll to selected day.

5. **`iBurn/ListView/EventRowView.swift`** — Event-specific row showing: type emoji, title, host/location, description, color-coded status ("Now · Xm left", "Starts in Xm", time + duration), distance, favorite heart.

6. **`iBurn/ListView/EventFilterSheet.swift`** — Filter form with: includeExpired toggle, onlyFavorites toggle, per-event-type toggles. Event type set is nil when all types selected (no filtering).

7. **`iBurn/ListView/EventListView.swift`** — Main view: day picker at top, sectioned List grouped by hour, toolbar (filter + map), loading/empty states, searchable.

8. **`iBurn/ListView/EventListHostingController.swift`** — UIKit bridge. Navigation to detail via `DetailViewControllerFactory.create(with: event.event)`. Map via `PlayaObjectAnnotation(event:)`.

### Modified Files

1. **`Packages/PlayaDB/Sources/PlayaDB/Filters/EventFilter.swift`**
   - Added `Codable` conformance
   - Added `startDate: Date?`, `endDate: Date?` for day-scoping
   - Added `eventTypeCodes: Set<String>?` for type filtering
   - Added `static func forDay(_ date: Date) -> EventFilter`

2. **`Packages/PlayaDB/Sources/PlayaDB/PlayaDBImpl.swift`**
   - `eventOccurrenceRequest(filter:)` now applies startDate/endDate range filtering
   - `eventObjectOccurrences(filter:db:)` now filters by eventTypeCodes

3. **`iBurn/ListView/FavoritesFilterable.swift`** — Added `extension EventFilter: FavoritesFilterable {}`

4. **`iBurn/ListView/DisplayableObject.swift`** — Added `extension EventObjectOccurrence: DisplayableObject {}`

5. **`iBurn/DependencyContainer.swift`** — Added `eventDataProvider` lazy property and `makeEventListViewModel()` factory

6. **`iBurn/BRCAppDelegate.m`** — Tab bar setup now calls `[self createEventsViewController]` instead of directly creating `EventListViewController`. Removed unused `dbManager` local variable.

7. **`iBurn/BRCAppDelegate+Dependencies.swift`** — Added `@objc func createEventsViewController() -> UIViewController` that checks `useSwiftUILists` feature flag.

8. **`iBurn/PlayaObjectAnnotation.swift`** — Added `convenience init?(event: EventObjectOccurrence)`

### Build / Tests

Build (succeeded, 0 errors, 0 warnings):
```bash
xcodebuild -workspace iBurn.xcworkspace -scheme iBurn -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.2,arch=arm64' 2>&1 | xcsift -f toon -w
```

iBurnTests (succeeded, 37 tests):
```bash
xcodebuild test -workspace iBurn.xcworkspace -scheme iBurnTests -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.2,arch=arm64' 2>&1 | xcsift -f toon -w
```

PlayaDB SPM tests (succeeded, 77 tests):
```bash
cd Packages/PlayaDB && swift test 2>&1 | xcsift -f toon -w
```

### Event Location Resolution (continued session)

Resolved the "Hosted by Camp"/"Located at Art" placeholder issue. Events store host camp/art as UIDs (`hostedByCamp`, `locatedAtArt`), not names.

**Changes:**

1. **`Packages/PlayaDB/Sources/PlayaDB/PlayaDB.swift`** — Added single-object fetch methods to protocol:
   - `func fetchArt(uid: String) async throws -> ArtObject?`
   - `func fetchCamp(uid: String) async throws -> CampObject?`
   - `func fetchEvent(uid: String) async throws -> EventObject?`

2. **`Packages/PlayaDB/Sources/PlayaDB/PlayaDBImpl.swift`** — Implemented the three fetch methods using `Column("uid")` filter with `fetchOne(db)` + `ensureMetadata`.

3. **`iBurn/ListView/EventDataProvider.swift`** — Changed `playaDB` from `private` to internal access so EventListViewModel can use it for host name resolution.

4. **`iBurn/ListView/EventListViewModel.swift`** — Added location resolution:
   - `@Published resolvedLocationNames: [String: String]` cache (event UID → host name)
   - `locationString(for:)` method returns resolved name or `otherLocation` fallback
   - `resolveLocationNames(for:)` called when items update, async resolves camp/art names via PlayaDB

5. **`iBurn/ListView/EventRowView.swift`** — Added `locationString: String?` parameter, replaced `event.primaryLocationString` usage.

6. **`iBurn/ListView/EventListView.swift`** — Passes `viewModel.locationString(for: event)` to EventRowView.

7. **`iBurn/Detail/ViewModels/DetailViewModel.swift`** — Event detail view location fix:
   - Added `resolvedHostName: String?` property
   - During `loadContent` event case, resolves host camp/art name via `playaDB.fetchCamp(uid:)` / `playaDB.fetchArt(uid:)`
   - `generatePlayaEventCellTypes` uses `resolvedHostName` with fallback to `otherLocation`
   - Removed TODO comment

## Context Preservation

### Architecture Decisions
- **Custom EventListViewModel** instead of generic ObjectListViewModel: Events need day selection (driving observation restarts), hourly grouping (computed property), and 60s refresh timer — none of which fit cleanly into the generic ViewModel.
- **Favorites per-event not per-occurrence**: The metadata table stores favorites by event UID. All occurrences of a favorited event show as favorited.
- **EventTypeInfo decoupled from BRCEventType**: Pure Swift struct avoids ObjC dependency. Codes verified from actual 2025 bundled JSON data.
- **ObjC bridge via factory method**: `createEventsViewController()` on BRCAppDelegate because tab bar setup is in ObjC.

### Feature Flag
Enable via: Settings > Feature Flags > "Use SwiftUI Lists" (DEBUG only).
When enabled, all three lists (Art, Camps, Events) use the new SwiftUI implementation.

## Cross-References
- Art/Camp list MVP: `/Docs/2026-01-10-grdb-list-view-mvp.md`
- Detail view + build fixes: `/Docs/2026-01-25-playadb-migration-next-steps.md`
- Event occurrence redesign: `/Docs/2025-08-03-playadb-event-occurrence-redesign.md`

## Expected Outcomes
- Events tab shows SwiftUI list when feature flag is enabled
- Day picker scrolls through festival days
- Events grouped by hour within selected day
- Status indicators show real-time event state (happening now, starting soon, ended)
- Filter sheet controls expired events, favorites, and event type filtering
- Search works across event name, description, type label
- Tapping an event navigates to the existing detail view
- Map button shows events with locations on the map
- Favorites persist via PlayaDB metadata

## Overall PlayaDB Migration Status

### Completed (behind `useSwiftUILists` feature flag)
| Component | Status | Key Files |
|-----------|--------|-----------|
| **Art List** | Done | `ArtListView`, `ArtDataProvider`, `ArtListHostingController` |
| **Camp List** | Done | `CampListView`, `CampDataProvider`, `CampListHostingController` |
| **Event List** | Done (this session) | `EventListView`, `EventDataProvider`, `EventListHostingController` |
| **Art Detail** | Done | `DetailView`, `DetailViewModel` (dual-mode: YapDB + PlayaDB) |
| **Camp Detail** | Done | Same unified detail views |
| **Event Detail** | Done | Host camp/art name resolution via PlayaDB single-object fetch |
| **Map Pins** | Done | `PlayaObjectAnnotation` (art, camp, event convenience inits) |
| **Favorites** | Done | PlayaDB-only, dual observation pattern |
| **Metadata** | Done | Notes, lastViewed, isFavorite via PlayaDB API |
| **Audio Tours** | Done | `AudioTourButton` + `BRCAudioPlayer` (Art list only) |
| **Cell Parity** | Done (Art/Camp) | `MediaObjectRowView`, `RowAssetsLoader`, thumbnails, colors |

### Not Yet Started
| Component | Notes |
|-----------|-------|
| **Favorites tab** | Still fully YapDB (`FavoritesViewController`) |
| **Nearby tab** | Still fully YapDB (`NearbyViewController`) |
| **Search (global)** | Still YapDB. PlayaDB has FTS5 but not wired to global search |
| **Data sync/updates** | `BRCDataImporter` still writes to YapDB. `PlayaDBSeeder` seeds from bundled JSON |

### Known Issues
- **PlayaKitTests scheme**: Broken — references non-existent target `D960F24D1F74E65A00144290`. The actual PlayaDB tests run fine via `swift test`.
- **Event detail location string**: ~~Shows "Hosted by Camp" placeholder~~ FIXED — resolves actual camp/art names via PlayaDB single-object fetch.

## Remaining Work (Future Sessions)
- **Event list tests**: Unit tests for EventListViewModel (day selection, grouping, filter persistence)
- **PlayaDB filter tests**: Tests for new EventFilter date range and event type code filtering
- **Remove LegacyDataStore**: Clean up YapDB bridge from Art/Camp navigation
- **Comprehensive QA**: Manual testing with feature flag enabled on device
- **Protocolize BRCMediaDownloader**: Dependency injection for media lookups (testability)
- **Favorites tab migration**: Replace YapDB-backed FavoritesViewController with PlayaDB
- **Data sync migration**: Wire `BRCDataImporter` updates to PlayaDB (or replace entirely)

## Branch & Repo Status
- **Branch**: `playadb-migration`
- **Working tree**: Modified (uncommitted changes from this session)
- **Last commit**: `4bb6923` ("Working on some more stuff")
