# 2026-05-16 — Event List Day-Tab Performance: Filter-Keyed Observation + JOIN

## High-Level Plan

### Problem
Day-tab switching in the SwiftUI events list took 2–3 seconds. The old UIKit + YapDatabase implementation was instant. Two structural issues combined:

1. **Observation churn.** `EventListViewModel.restartObservation()` (iBurn/ListView/EventListViewModel.swift:163) tore down and rebuilt the `ValueObservation` on every `selectedDay.didSet`.
2. **Six sequential queries per fetch.** Inside the fetch closure (PlayaDBImpl.swift:1107): `event_occurrences` range → `event_objects IN(…)` → `camp_objects IN(…)` → `art_objects IN(…)` → `object_metadata IN(…)` → `thumbnail_colors IN(…)`. With 500–1000 occurrences/day each IN clause carried hundreds of UIDs.

YapDB pre-computed group membership at write time, so day-switching was a group-visibility toggle. GRDB was doing far more work per tap than necessary.

### Solution
**Separate "what triggers an observation restart" from "what slices the result":**

- Observation is keyed on the **filter** (favorites, event types, year, search) — *not* on the day. Filter changes restart with new SQL `WHERE`. Result is the full filter-matching set across all 7 festival days.
- Day-switching is a pure UI slice over an in-memory `[Date: [EventHourSection]]` cache built by the observation. Zero DB work per tab tap.
- A single JOIN replaces the 4 sequential entity queries, decoded through the existing `EventOccurrenceJoinedRow`.
- Remaining Swift filters (favorites EXISTS, year, eventTypeCodes) pushed into SQL. Region/bbox stays Swift-side.
- `bucketByDayThenHour` does a single sequential split (no `Dictionary(grouping:)` hashing) since the JOIN result is already `ORDER BY start_time`.

Mirrors YapDB behavior: filter-change rebuilds the filtered view, day-change is a group-visibility toggle.

### Why this approach over alternatives
- **DB-driven filter table** (storing UI state in a singleton DB row so the observation re-fires on every day change): would not actually solve the perf problem — fetches still rerun per tap. Mixes UI state into schema, adds feedback-loop fragility. Rejected.
- **Per-day caching with map of past results**: solves repeat-tap latency but every cold tap still costs the full fetch. More moving parts than the full-festival load. Rejected.
- **Stored `start_hour`/`start_day` columns**: timezone footgun (`Calendar.current` vs SQLite UTC `strftime`), microseconds saved at this scale. Skipped, reserved as contingency if profiling later shows grouping >50ms.
- **Additional composite index**: existing `idx_event_occurrences_start_time` already covers the sort. Skipped pending profile data.

## Technical Details

### Files modified
- `Packages/PlayaDB/Sources/PlayaDB/PlayaDBImpl.swift` — added `eventObjectOccurrencesJoined(filter:db:)`, `observeEventsByDayThenHour(...)`, `bucketByDayThenHour(_:)`. Tracked regions broadened to include `ObjectMetadata` + `ThumbnailColors` so favorite/color writes re-emit.
- `Packages/PlayaDB/Sources/PlayaDB/PlayaDB.swift` — added `observeEventsByDayThenHour` protocol method.
- `Packages/PlayaDB/Sources/PlayaDB/Models/EventObjectOccurrence.swift` — `EventOccurrenceJoinedRow` gained explicit memberwise `init(...)` (preserves existing test usage) and `init(row:)` that decodes nested association scopes. Camp/art scopes are nested under the `event` scope because the associations chain off `EventObject`.
- `iBurn/ListView/EventDataProvider.swift` — added `observeObjectsByDayThenHour(filter:)` AsyncStream wrapper.
- `iBurn/ListView/EventListViewModel.swift` — `selectedDay.didSet` no longer restarts observation; added `dayBuckets: [Date: [EventHourSection]]` published storage; `browseSections` became a computed property over `dayBuckets[selectedDay]`; `browseFilter` no longer injects `startDate`/`endDate`; `restartObservation` subscribes to the day-then-hour stream in browse mode.
- `Packages/PlayaDB/Tests/PlayaDBTests/EventListBucketObservationTests.swift` — new test file (4 tests).

### Key code paths

**JOIN composition** (PlayaDBImpl.swift):
```swift
let eventAssociation = EventOccurrence.event.forKey("event")
var request = eventOccurrenceRequest(filter: filter, matchingEventUIDs: matchingEventUIDs)
    .including(required: eventAssociation
        .including(optional: EventObject.hostedCamp)
        .including(optional: EventObject.locatedArt))
```
`.forKey("event")` overrides GRDB's default scope key (destination type name) so the decoded row exposes the EventObject row under `row.scopes["event"]`.

**Single-pass bucketing**: rows arrive pre-sorted by `start_time` from the JOIN, so a sequential walk into `currentDay`/`currentHour` accumulators replaces `Dictionary(grouping:).sorted()`.

**Tracked observation regions** for `observeEventsByDayThenHour`:
```swift
[EventOccurrence.all(), EventObject.all(), ObjectMetadata.all(), ThumbnailColors.all()]
```
Intentionally excludes `camp_objects` / `art_objects` — host edits don't reshuffle the event list (parity with existing `observeEvents`).

### Tests added
- `testBucketGroupsByDayThenHour` — multi-day fixtures bucket cleanly; sections ordered by hour; rows within a section preserve start_time order.
- `testJoinedFetchResolvesHostCamp` — `hostName` is populated from the JOIN, not a separate query.
- `testFavoriteToggleReEmits` — writing to `object_metadata` re-fires the observation.
- `testOnlyFavoritesFilterAppliesAtSqlLevel` — `onlyFavorites = true` pushed into SQL via EXISTS; non-favorited rows excluded.

## Context Preservation

### Debugging incidents
1. **"Missing 'event' scope in joined row"** — GRDB defaults the scope key on a `belongsTo` to the destination type's name (`"eventObject"`), not the static property name (`event`). Fix: `.forKey("event")` on the association.
2. **Host camp not resolved in JOIN** — first attempt looked for `hostedCamp` at the top-level `row.scopes`. The scope is actually nested under the `event` scope because `EventObject.hostedCamp` chains off `EventObject`, not `EventOccurrence`. Fix: `eventRow.scopes["hostedCamp"]`.
3. **Favorite toggle didn't re-emit** — first version mirrored the existing `observeEvents`' tracked-region set (`[EventOccurrence.all(), EventObject.all()]`), which excludes `ObjectMetadata`. Fix: include `ObjectMetadata.all()` and `ThumbnailColors.all()` in the new observation's tracked regions.

### What changed in EventListViewModel
- `browseSections` is no longer `@Published` storage — it's a computed view over `dayBuckets[selectedDay]`. SwiftUI re-renders correctly because both `dayBuckets` and `selectedDay` are `@Published`.
- `selectedDay.didSet` is empty — the observation does not restart. Day-tab switching becomes O(1) in memory.
- `browseFilter()` drops `startDate`/`endDate` — the observation now produces the full festival, sliced by the UI.

### What is NOT changed
- The legacy `observeEvents` / `observeEventsByHour` / `eventObjectOccurrences` (non-JOIN) helpers are still in place. They're used by `fetchEvents`, `fetchEvents(on:)`, etc. Cleanup is deferred to a follow-up PR — risk-free now since they share none of the modified code paths.
- The search (FTS) mode in `EventListViewModel` is unchanged. It still flows through `observeObjects(filter:)` → flat `searchResults`.

## Expected Outcomes

After this change:
- Day-tab switching performs **zero DB queries** (verified by the observation only being restarted on filter changes).
- Filter changes run one JOIN query instead of six sequential queries (verified by inspection of `eventObjectOccurrencesJoined`).
- Favorite toggles still update the UI (verified by `testFavoriteToggleReEmits`).
- All 136 existing PlayaDB tests + 4 new tests pass.

## Cross-References

- Plan file: `/Users/chrisbal/.claude/plans/okay-i-want-to-tingly-bee.md`
- Related: `Docs/2025-08-03-playadb-event-occurrence-redesign.md` (introduced `EventObjectOccurrence` composite)
- Related: `Docs/2025-07-09-grdb-transition-complete.md` (initial GRDB migration context)
