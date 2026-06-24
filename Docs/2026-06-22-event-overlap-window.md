# 2026-06-22 — Overlap-aware event time window (`EventFilter.activeWindow`)

**Date:** 2026-06-22 (Pacific)
**Branch:** `event-window-overlap` (off the now-green `origin/master` @ `59adeda`)
**Master plan:** `~/.claude/plans/what-were-we-up-zippy-dongarra.md` (Phase A2)
**Follows:** [2026-06-19-merge-repair-and-sync.md](2026-06-19-merge-repair-and-sync.md)

---

## Context / why

The shared event query helper `eventOccurrenceRequest(filter:)`
(`Packages/PlayaDB/Sources/PlayaDB/PlayaDBImpl.swift`) filtered the time window by the
occurrence's **start** only:

```swift
if let startDate = filter.startDate { request = request.filter(startTime >= startDate) }
if let endDate   = filter.endDate   { request = request.filter(startTime <  endDate) }
```

So a query for "events in window [from, to)" **dropped events that started before `from` but are
still running** — the classic interval bug. Sibling methods already do it right
(`fetchEvents(from:to:)`: `start_time < endDate && end_time > startDate`).

This is the documented Phase A2 prerequisite for unifying Nearby / Right Now, and it independently
fixes a real bug in the AI "Right Now" flow (see below).

## Design decision — additive, not a global flip

An Explore pass suggested simply flipping `eventOccurrenceRequest` to overlap globally, arguing the
day-tab list is unaffected (true — it clears `startDate`/`endDate` and buckets by start day in
`bucketByDayThenHour`). But a global flip **would** change two release features:

- `PlayaDBAnnotationDataSource` "today's favorites on map" and `FavoritesViewModel` "today only"
  set `startDate = startOfDay, endDate = nextDay`. Under overlap they'd start including events that
  *started* on a previous day but run into today — and **multi-day occurrences would appear on
  every day they span**, inconsistent with how the day-tab buckets by start day.

So instead of changing `startDate`/`endDate` semantics, this adds a **distinct, opt-in** field.
Zero behavior change for every existing consumer.

## Changes

- **`Filters/EventFilter.swift`** — new `public var activeWindow: DateInterval?`. Added as the
  **last** init parameter (`activeWindow: DateInterval? = nil`) — deliberately at the end to avoid
  the positional/labeled-arg ordering break that took down `master` last session. `DateInterval` is
  `Codable`+`Hashable`, so `EventFilter`'s synthesized conformances still hold.
- **`PlayaDBImpl.eventOccurrenceRequest(filter:)`** — when `activeWindow` is set, apply the overlap
  predicate (same form as `fetchEvents(from:to:)`):
  ```swift
  if let window = filter.activeWindow {
      request = request
          .filter(EventOccurrence.Columns.startTime < window.end)
          .filter(EventOccurrence.Columns.endTime   > window.start)
  }
  ```
  Independent of `startDate`/`endDate`, which keep their start-bounded calendar-day meaning.
- **`iBurn/AISearch/Workflows/RightNowWorkflow.swift`** (`regionQuery`) — switched from
  `startDate = max(windowStart, now)` / `endDate = windowEnd` to
  `activeWindow = DateInterval(start: floor, end: windowEnd)` (`floor = max(windowStart, now)`), with
  a `guard floor < windowEnd else { return [] }` so an empty/past window can't form an inverted
  `DateInterval` (preserves the old "empty window → no rows" behavior). **Bug fixed:** the region
  query now surfaces events already underway at `floor`; previously the start-bounded SQL prefilter
  dropped them *before* the workflow's client-side overlap gate (`occ.startDate < windowEnd &&
  occ.endDate > windowFloor`) ever saw them. The client-side gate stays — it still unifies the
  separately-fetched camp/art-hosted occurrences.

## Tests

- **`FilterRequestBuilderTests.testEventOccurrenceRequestActiveWindowKeepsInProgressEvents`** (new) —
  inserts ongoing / in-window / ended / later events; asserts start-bounded returns `["in-window"]`
  while `activeWindow` returns `["ongoing", "in-window"]`. Documents both behaviors so the
  distinction can't silently regress. Uses `try XCTUnwrap(playaDB as? PlayaDBImpl)` (no force-unwrap).

## Verification

- PlayaDB `swift test --filter FilterRequestBuilderTests`: **15 passed** (incl. the new test).
- `xcodebuild build` (iBurn, iPhone 17 Pro Max, iOS 26.2): **0 errors**, 6 pre-existing warnings.

## Not done / follow-ups

- **NearbyCard / NearbyViewModel** still fetch region events and gate "happening now" client-side.
  They *could* adopt `activeWindow` (small payoff — the region is tiny and the window is a point at
  `now`), left as a deliberate follow-up.
- The camp/art-hosted-events expansion in `RightNowWorkflow` stays — it covers events whose host GPS
  isn't in the R*Tree join, which is a coverage concern orthogonal to the time-window fix.
- Not yet committed (awaiting authorization).
