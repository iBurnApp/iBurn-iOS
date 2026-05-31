# Events: Hour Quick-Scroll Index + FTS Search (SwiftUI parity)

## High-Level Plan

Two parallel Events implementations sit behind `Preferences.FeatureFlags.useSwiftUILists`. Closing the gap between them surfaces three coupled problems, all rooted in the SwiftUI version short-cutting the data layer.

| Concern | UIKit (legacy) | SwiftUI (current) | Plan |
|---|---|---|---|
| Hour grouping | YapDB view groups by `"YYYY-MM-dd HH"` — sections come pre-shaped from DB | Flat `[ListRow]` from `observeEvents`; VM re-groups in memory via `Calendar` | Move grouping into `PlayaDB.observeEventsByHour` |
| Side index strip | `UITableView.sectionIndexTitles` — bare hour digits, tap + drag-scrub | Absent | Build `EventHourIndexView` (vertical strip, `ScrollViewReader` + `DragGesture`) |
| Search | Separate `searchViewName` YapDB view (FTS) | `EventFilter.searchText` consumed post-fetch by `.lowercased().contains()` in `eventObjectOccurrences` | Apply `.matching(searchText:)` at SQL via FTS5 sub-select; switch the VM to a separate observation when search is active |

**Latent bug**: `PlayaDBImpl.eventObjectOccurrences` (lines 1036-1043) does in-memory `.contains()` filtering for `filter.searchText`, ignoring the existing `event_objects_fts` table. Art/Camp/MV all correctly use `.matching(searchText:)`. Fixing this also benefits the AI-tool callers (`PlayaSearchTools`).

User decisions captured:
- Hide inline section headers; rely on the strip alone.
- Tap + drag-scrub with light haptic.
- Bare hour digits (`12, 1, 2, ...`) — `12` appears twice per Apple's index convention.
- Grouping lives in the DB layer; the VM consumes already-shaped sections.
- Search is a separate DB observation, not a filter applied to the browse stream.
- Trust DB observations — no optimistic UI mutations on toggle/edit.

## Architecture

```
Browse mode (search empty):
  EventFilter{day-scoped, no searchText}  →  observeEventsByHour  →  [EventHourSection]
                                                                       │
                                                   sectioned List + hour strip overlay

Search mode (search non-empty):
  EventFilter{searchText, all days}  →  observeEvents  →  [ListRow<EventObjectOccurrence>]
                                                                       │
                                                          flat List, no strip
```

The VM owns one task at a time and swaps which observation it consumes when `searchText` crosses the empty/non-empty boundary.

## Technical Details

### A. PlayaDB layer

#### A1. Create `Packages/PlayaDB/Sources/PlayaDB/Models/EventHourSection.swift`

```swift
public struct EventHourSection: Equatable, Sendable {
    public let hour: Int                                // 0-23
    public let rows: [ListRow<EventObjectOccurrence>]
    public init(hour: Int, rows: [ListRow<EventObjectOccurrence>]) {
        self.hour = hour
        self.rows = rows
    }
}
```

#### A2. Fix events FTS in `PlayaDBImpl.eventOccurrenceRequest(filter:)` (line 963)

`.matching(searchText:)` keys off `RowDecoder.databaseTableName + "_fts"`. The events FTS table is `event_objects_fts` (indexes `EventObject` columns), so we apply the match against `EventObject` and constrain `EventOccurrence.event_id`:

```swift
if let searchText = filter.searchText, !searchText.isEmpty {
    let matchedEvents = EventObject
        .matching(searchText: searchText)
        .select(EventObject.Columns.uid)
    request = request.filter(matchedEvents.contains(EventOccurrence.Columns.eventId))
}
```

Then **delete** the in-memory `searchText` block in `eventObjectOccurrences(filter:db:)` (lines 1036-1043).

#### A3-A4. Add `observeEventsByHour` to PlayaDB protocol + impl

```swift
@discardableResult
func observeEventsByHour(
    filter: EventFilter,
    onChange: @escaping ([EventHourSection]) -> Void,
    onError: @escaping (Error) -> Void
) -> PlayaDBObservationToken
```

Implementation delegates to `observeEvents` and groups before emitting via a `static internal` `groupByHour` helper (testable).

### B. App data-provider

`iBurn/ListView/EventDataProvider.swift` gains `observeObjectsByHour` (AsyncStream wrapper, same cancellation pattern as existing `observeObjects`).

### C. ViewModel

`iBurn/ListView/EventListViewModel.swift`:

```swift
enum Mode: Equatable { case browse, case search(String) }

@Published var browseSections: [EventHourSection] = []
@Published var searchResults: [ListRow<EventObjectOccurrence>] = []
@Published var searchText: String = "" { didSet { restartObservation() } }
var mode: Mode { searchText.isEmpty ? .browse : .search(searchText) }

func toggleFavorite(_ row: ListRow<EventObjectOccurrence>) async {
    do { try await dataProvider.toggleFavorite(row.object) }
    catch { print("Error toggling favorite for \(row.object.name): \(error)") }
}
```

`restartObservation()` cancels current task, starts the right one for current mode (browse subscribes to `observeObjectsByHour`; search subscribes to `observeObjects` with day-unscoped filter). No optimistic UI mutations — trust the DB observation.

### D. View

`iBurn/ListView/EventHourIndexView.swift` (new) — vertical strip, ScrollViewReader integration, `DragGesture(minimumDistance: 0)` for tap+drag-scrub, light haptic on hour change. Uses `PreferenceKey` to track each label's frame in a named coordinate space, so drag location maps to hour.

`iBurn/ListView/EventListView.swift` branches on `viewModel.mode`:
- Browse: day picker + flat-rendered List (rows from each section, with `.id(section.hour)` only on the first row of each section) + `EventHourIndexView` overlay.
- Search: hides day picker, shows flat results, no strip.

### E. Tests

- `EventHourSectionTests.swift` — covers `groupByHour` ordering / empty / single-hour edge cases.
- Update `FilterRequestBuilderTests.testEventRequestAppliesAllFilters` to assert FTS5 SQL behavior (e.g., stemming match) instead of in-memory `.contains()`.

## Cross-References

- Plan file: `~/.claude/plans/we-still-have-a-sorted-prism.md`
- Memory: `feedback_trust_db_observations.md`, `feedback_fts_for_search.md`, `feedback_fully_inflated_data_objects.md`
- Prior SwiftUI Events work: `Docs/2026-04-12-ai-event-summary.md`, `Docs/2026-04-13-event-host-name-location-in-cells.md`
- Reused patterns:
  - `iBurn/ListView/EventDayPickerView.swift:21-61` — ScrollViewReader pattern (horizontal version of what we're building)
  - `iBurn/EventListViewController.swift:18-19, 37-43, 112-123` — UIKit two-view (browse/search) precedent + hour-digit transform
  - `Packages/PlayaDB/Sources/PlayaDB/QueryExtensions/QueryInterfaceRequest+DataObject.swift:114-133` — generic `.matching(searchText:)`
  - `Packages/PlayaDB/Sources/PlayaDB/PlayaDBImpl.swift:887-941` — Art/Camp/MV correct FTS application (mirror for events)

## Expected Outcomes

1. Events list (SwiftUI build) shows a tappable + drag-scrubbable hour strip on the right edge with bare hour digits matching UIKit's strip exactly.
2. Inline `12 AM`/`1 AM` headers no longer render between rows (UIKit parity).
3. Typing in the search bar switches the list to FTS-backed flat results (stemming/unicode match), hides the day picker and strip.
4. Clearing the search returns to browse mode with the prior selected day intact.
5. Favorite toggles don't flicker — the DB observation is the source of truth.
6. AI-tool event search (`PlayaSearchTools`) gains FTS tokenization for free.
7. UIKit code path stays untouched and continues to work when `useSwiftUILists` is OFF.
