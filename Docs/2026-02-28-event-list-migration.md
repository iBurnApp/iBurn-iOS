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
- **showMap crash on duplicate keys**: ~~`Dictionary(uniqueKeysWithValues:)` in `EventListHostingController.showMap(for:)` crashed when multiple `EventObjectOccurrence`s shared the same underlying `EventObject` (same event, different time slots). 1304 events → 1230 unique keys.~~ FIXED — replaced with `Dictionary(_:uniquingKeysWith:)` to keep first occurrence.

## Remaining Work (Future Sessions)
- **Event list tests**: Unit tests for EventListViewModel (day selection, grouping, filter persistence)
- **PlayaDB filter tests**: Tests for new EventFilter date range and event type code filtering
- **Remove LegacyDataStore**: Clean up YapDB bridge from Art/Camp navigation
- **Comprehensive QA**: Manual testing with feature flag enabled on device
- **Protocolize BRCMediaDownloader**: Dependency injection for media lookups (testability)
- **Favorites tab migration**: Replace YapDB-backed FavoritesViewController with PlayaDB
- **Data sync migration**: Wire `BRCDataImporter` updates to PlayaDB (or replace entirely)

---

## Session 2: Dual-Backend Event Detail View

### Problem
The SwiftUI `DetailView` renders event details from `DetailCellType`. Two code paths exist:
- **Legacy** (`generateEventCells`): Comprehensive — host relationship, schedule with color-coded time, event type, next event by host, "all events by host" link, host description
- **PlayaDB** (`generatePlayaEventCellTypes`): Minimal — only title, description, location, URL, notes

The PlayaDB path couldn't produce the full set because several `DetailCellType` cases carried legacy ObjC types as associated values. Additionally, the event list passed `EventObject` (no timing) instead of `EventObjectOccurrence`.

### Solution: Value Types + Closures
Changed cell type associated values from concrete ObjC types to plain Swift values + closures for tap actions. The ViewModel constructs closures at cell-generation time, capturing coordinator + objects.

### Files Modified

| File | Change |
|------|--------|
| `Packages/PlayaDB/.../PlayaDB.swift` | Added `fetchEvents(hostedByCampUID:)` and `fetchEvents(locatedAtArtUID:)` protocol methods |
| `Packages/PlayaDB/.../PlayaDBImpl.swift` | Implemented both fetch methods — filter by `hosted_by_camp`/`located_at_art`, join occurrences, sort by startDate |
| `iBurn/Detail/Models/DetailSubject.swift` | Added `.eventOccurrence(EventObjectOccurrence)` case, updated all computed properties |
| `iBurn/Detail/Models/DetailCellType.swift` | Decoupled 4 cell cases from ObjC types (relationship, nextHostEvent, eventRelationship→count-based, eventType→emoji+label), added `.navigateToViewController` action |
| `iBurn/Detail/Views/DetailView.swift` | Updated 4 cell view structs to use plain values, updated `isCellTappable` for closure-based nil checks |
| `iBurn/Detail/ViewModels/DetailViewModel.swift` | Updated handleCellTap (closures), legacy cell gen (closures + new signatures), added `generatePlayaEventOccurrenceCellTypes` with comprehensive cells, added `formatEventTimeAndDuration` static helper, added `formatPlayaEventSchedule`, added resolved host properties, handled `.eventOccurrence` in all switch cases |
| `iBurn/Detail/Services/DetailActionCoordinator.swift` | Handle `.navigateToViewController(let vc)` |
| `iBurn/Detail/Controllers/DetailViewControllerFactory.swift` | Added `create(with: EventObjectOccurrence, playaDB:)` factory method |
| `iBurn/ListView/EventListHostingController.swift` | Pass full `EventObjectOccurrence` to detail factory instead of `.event` |

### New File Created

| File | Purpose |
|------|---------|
| `iBurn/Detail/Controllers/PlayaHostedEventsViewController.swift` | UIHostingController wrapping SwiftUI list of hosted events. Used for "See all N events" tap. |

### Key Design Decisions

1. **Closures over protocols**: Cell types carry `onTap: (() -> Void)?` closures instead of requiring protocol conformance on legacy objects. ViewModel constructs closures at cell-generation time, keeping views purely presentational.

2. **`eventOccurrence` vs `event`**: Added a distinct `DetailSubject.eventOccurrence` case rather than converting to `.event` so the detail screen has access to timing info for schedule display.

3. **Resolved host properties**: During `loadData`, the ViewModel resolves host camp/art details (name, subject, description, location, events) and caches them as private properties. This avoids async calls during cell generation.

4. **Static `formatEventTimeAndDuration`**: Extracted from the old `DetailNextHostEventCell` view into a static method on `DetailViewModel` so it can be shared between legacy cell generation, PlayaDB cell generation, and the hosted events list.

### Build Status
- **Build**: 0 errors, 0 warnings
- **Existing tests**: Not affected (legacy path produces same behavior, just with new signatures)

---

## Session 3: Match EventRowView to Old UIKit Event Cell Design

### Problem
The new SwiftUI `EventRowView` did not match the original UIKit `BRCEventObjectTableViewCell` layout from the XIB. Key differences:
- Missing camp/art thumbnail image (75×75 next to description)
- Missing playa address on the right side of the host name row
- Missing host description appended to event description
- Layout order was wrong (emoji on left, heart on right)
- Time/status format didn't match old ObjC format (missing day abbreviation, different "starting soon" format)
- No image color theming from camp thumbnails

### Solution
Restructured `EventRowView` to match the old XIB layout exactly, expanded `EventListViewModel` to resolve full host data (not just names), and added `RowAssetsLoader` integration for camp thumbnails + color theming.

### Files Modified

| File | Change |
|------|--------|
| `iBurn/ListView/EventListViewModel.swift` | Added `ResolvedEventHost` struct (name, address, description, thumbnailObjectID, isArt). Replaced `resolvedLocationNames: [String: String]` with `resolvedHosts: [String: ResolvedEventHost]`. Renamed `resolveLocationNames()` → `resolveHosts()` which now fetches camp address (`locationString`), art address (`locationString ?? timeBasedAddress`), descriptions, and UID for thumbnail loading. Added `resolvedHost(for:)` accessor. |
| `iBurn/ListView/EventRowView.swift` | Complete rewrite. New parameters: hostName, hostAddress, hostDescription, campUID, isArtHosted. New layout matching old XIB: Row1=[Heart][Title][TypeEmoji], Row2=[HostName]...[Address], Row3=[Thumbnail 75×75][Description], Row4=[Distance]...[Time/Status]. Added `@StateObject RowAssetsLoader` for camp thumbnail + `ImageColors` theming. Combined description (event + host). Status text matches old ObjC format ("Mon 10:00am (duration)", "Starts Xm (duration)", "10:00am (Xm left)"). Art hosts prefixed with 🎨. List row background tinted from image colors. |
| `iBurn/ListView/EventListView.swift` | Extracted `eventRow(for:)` helper. Passes full host data: hostName (with otherLocation fallback), hostAddress, hostDescription, campUID, isArtHosted from `viewModel.resolvedHost(for:)`. |

### Layout Comparison (Old XIB vs New SwiftUI)

```
Old UIKit Cell (BRCEventObjectTableViewCell.xib):
┌─────────────────────────────────────────────────┐
│ [♡25×25] [Title.....................] [🍺25px]  │
│ [Host Name...........] [6:30 & A right-aligned] │
│ [Thumb 75×75] [Description text wrapping to     │
│              │  multiple lines within 75px ht]   │
│ [🚶 20m 🚴 5m.......] [10:00am - 12:00pm]      │
└─────────────────────────────────────────────────┘

New SwiftUI Cell (EventRowView):
┌─────────────────────────────────────────────────┐
│ [♡25×25] [Title.....................] [🍺25px]  │
│ [Host Name...........] [6:30 & A right-aligned] │
│ [Thumb 75×75] [Description text wrapping to     │
│              │  multiple lines within 75px ht]   │
│ [🚶 20m 🚴 5m.......] [mon 10:00am (2h)]       │
└─────────────────────────────────────────────────┘
```

### Key Design Decisions

1. **RowAssetsLoader with empty ID**: When no campUID exists, `RowAssetsLoader` is created with empty string ID — it will find no thumbnail and do no work. This avoids optional StateObject complexity.

2. **ImageColors theming**: Follows same pattern as `ObjectRowView` — when `RowAssetsLoader` extracts colors from the camp thumbnail, the entire row's text colors shift to match. Background also tints via `listRowBackground`.

3. **Combined description**: Event description + host (camp/art) description joined with newline, matching the old ObjC logic in `BRCEventObjectTableViewCell.m:114-119`.

4. **Status text format**: Matches old ObjC `defaultEventText` format: "Mon 10:00am (2h)" lowercased. "Starting soon" shows duration: "Starts 5m (2h)". "Currently happening" shows time left: "10:00am (45m left)".

### Build Status
- **Build**: Succeeded (0 errors, 0 warnings)

---

## Session 4: Close Gaps Between PlayaDB and Legacy Detail Screens

### Problem
An audit of PlayaDB detail screens vs legacy (YapDB) screens identified three categories of missing features:
1. **Event detail**: Missing host image, map, GPS coordinates, distance, travel time
2. **Art/Camp detail**: Missing hosted events (next event + all events cells)
3. **Footer duplication**: Art/camp/event paths duplicated identical footer cell logic (map, GPS, distance, travel time, notes)

Visit status was intentionally deferred — requires a PlayaDB schema migration.

### Solution
All changes confined to `iBurn/Detail/ViewModels/DetailViewModel.swift` (142 insertions, 36 deletions).

### Changes Made

#### 1. Four shared helper methods added (after `distanceToLocation`)
- **`effectiveLocation(for: EventObjectOccurrence)`** — Returns event's own GPS or falls back to host camp/art location
- **`eventAnnotation(for: EventObjectOccurrence)`** — Returns event annotation or falls back to host camp/art annotation
- **`generatePlayaFooterCells(...)`** — Shared footer: map (if image), GPS coordinates, distance, travel time, user notes
- **`generateHostedEventCells(hostName:)`** — Next upcoming event + "All N events" button for camp/art detail screens

#### 2. Host event resolution in `loadContent`
- **Art case**: Added `resolvedHostEvents = (try? await playaDB.fetchEvents(locatedAtArtUID: art.uid)) ?? []`
- **Camp case**: Added `resolvedHostEvents = (try? await playaDB.fetchEvents(hostedByCampUID: camp.uid)) ?? []`

#### 3. `generatePlayaArtCellTypes` — hosted events + refactored footer
- Added `generateHostedEventCells(hostName: art.name)` after URL cell
- Replaced 19 lines of duplicated map/GPS/distance/travelTime/notes with `generatePlayaFooterCells(...)` call

#### 4. `generatePlayaCampCellTypes` — hosted events + refactored footer
- Added `generateHostedEventCells(hostName: camp.name)` after URL cell
- Replaced 15 lines of duplicated footer logic with `generatePlayaFooterCells(...)` call

#### 5. `generatePlayaEventOccurrenceCellTypes` — host image, map, footer
New cell sequence:
| # | Cell | Source |
|---|------|--------|
| 1 | Host image | `localThumbnailURL(objectID: hostUID)` |
| 2 | Map (if no image) | `eventAnnotation(for: occ)` |
| 3 | Title | `occ.name` |
| 4 | Description | `occ.description` |
| 5 | Host relationship | `resolvedHostName` / `resolvedHostSubject` |
| 6 | Next host event | `resolvedHostEvents` (filtered) |
| 7 | All host events | `resolvedHostEvents` |
| 8 | Schedule | `formatPlayaEventSchedule(occ:)` |
| 9 | Location address | `resolvedHostLocation` / `occ.otherLocation` |
| 10 | Event type | `EventTypeInfo` |
| 11 | Host description | `resolvedHostDescription` |
| 12 | Contact email | `occ.contact` |
| 13 | Website | `occ.url` |
| 14–18 | Footer | `generatePlayaFooterCells(...)` with `effectiveLocation(for: occ)` |

Key additions vs previous code:
- Host image at top (from camp or art thumbnail)
- Map before title when no host image
- Full footer with map-if-image, GPS, distance, travel time (replaced bare `.userNotes`)

### Build Status
- **Build**: Succeeded (0 errors, 0 warnings)
- **Tests**: `iBurnTests` has pre-existing compilation error in `DetailViewModelTests.swift:252` (old `DetailCellType.relationship` signature) unrelated to this change. The 4 data import tests pass.

### Deferred
- **Visit status**: PlayaDB `ObjectMetadata` lacks a `visitStatus` column. Requires GRDB migration + new API surface. Tracked separately.

## Branch & Repo Status
- **Branch**: `playadb-migration`
- **Working tree**: Modified (uncommitted changes from this session)
- **Last commit**: `5cc81a2` ("More siwftui updates")
