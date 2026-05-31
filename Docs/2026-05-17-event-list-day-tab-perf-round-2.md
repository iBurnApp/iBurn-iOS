# 2026-05-17 — Event List Day-Tab Performance, Round 2: SwiftUI Render Layer

## High-Level Plan

### Problem
Round 1 (see `Docs/2026-05-16-event-list-day-tab-perf.md`) collapsed the DB hot path: single long-lived observation, single JOIN, in-memory day-then-hour bucket. Tests passed and the DB layer was confirmed zero-work on tap. **But on a real device (BigPhone 17), day-tab switching was still felt as 2–3s.**

### Investigation
Added DEBUG-only `print`-based timing at the hot points and captured a console log via `xcrun devicectl device process launch --console`. Three concrete findings:

1. **Day-swap was 442–610ms**, not 2–3s — but still a perceptible freeze. Pattern: `EventListView.body` fires within ~2ms of `selectedDay.didSet`, then a 400–600ms gap before the first `row.body`. That gap is SwiftUI's `List` setting up internal structure for 1267–1654 rows.
2. **Startup had a metadata feedback loop**: ObjectMetadata was added to the new observation's tracked regions (so favorite toggles re-emit), and `observeListRows` always spawns a `Task { ensureMetadata(...) }` after each emission. Initial fetch inserted ~8000 blank metadata rows, which the ObjectMetadata region observed and re-fired the JOIN. Two full fetches at startup (220ms + 758ms ≈ 1s wasted).
3. **`bucketByDayThenHour` regressed to 1306ms** (was 22ms) due to ~16,712 `Calendar.startOfDay`/`component` calls under device load.

### Fix
Three changes, layered:

1. **Replace `List` with `ScrollView { LazyVStack { ... } }`** in `EventListView.body`. SwiftUI's `List` pre-processes all row identities on diff/recreate, costing O(rows) on every day swap regardless of laziness. `LazyVStack` only materializes rows entering the viewport. Lost: List's separators (replaced with `Divider()`) and swipe actions (rows didn't use either). **This is the win that landed the perceptual fix.**
2. **Cache `Calendar` boundaries** in `bucketByDayThenHour`. Rows arrive sorted by `start_time`, so consecutive rows nearly always share day + hour; only call `Calendar.startOfDay`/`component` when crossing a cached boundary. Cut ~16k Calendar calls to ~30. Bucket time: 1306ms → 4.8ms.
3. **`skipEnsureMetadata: true`** on the new `observeEventsByDayThenHour` observation. Adds an opt-out parameter to `observeListRows`. The fetch already tolerates nil metadata via `metaByID[uid]`, so blank pre-population is unnecessary for events. Eliminates the startup feedback loop. Initial fetch count: 2 → 1.

### Why not other approaches
- **`.id(selectedDay)` on the List** — tried it; made things marginally worse. Teardown-recreate costs ~the same as the diff because both are O(rows). Reverted.
- **Pre-compute display strings at bucket time / cache DateFormatters** — measured impact was negligible (per-render formatter cost was a few ms total, not the bottleneck). Skipped.
- **Collapse multiple occurrences per event into one row** — would have reduced row count 3-5×, but a UX change. Not needed once LazyVStack eliminated the SwiftUI cost.

## Technical Details

### Files modified
- `iBurn/ListView/EventListView.swift` — replaced `List { … }` + `.listStyle(.plain)` + `.listRowInsets(…)` with `ScrollView { LazyVStack(alignment: .leading, spacing: 0) { … .padding(insets) ; Divider() } }`. `ScrollViewReader`, `.searchable`, and the `EventHourIndexView` overlay all retained — they wrap the ScrollView the same way they wrapped List.
- `Packages/PlayaDB/Sources/PlayaDB/PlayaDBImpl.swift`
  - `bucketByDayThenHour(_:)` — added cached `currentDayEnd` (exclusive day upper bound) and `currentHourStart`/`currentHourEnd`. Day-boundary and hour-boundary checks skip `Calendar` calls when the row falls within the cached interval. Behavior unchanged; existing tests cover correctness.
  - `observeListRows<T>` — added `skipEnsureMetadata: Bool = false` parameter; gates the post-emission `Task { ensureMetadata(...) }` side effect.
  - `observeEventsByDayThenHour(...)` — passes `skipEnsureMetadata: true`. Comment notes the feedback-loop rationale.

### Measurements (BigPhone 17, Debug build)
| | Before round 2 | After round 2 |
| --- | --- | --- |
| Initial JOIN count | 2 (220ms + 758ms) | 1 (~220ms) |
| `bucketByDayThenHour` (8356 rows) | 1306ms | 4.8ms |
| Day-tab swap (didSet → first row body) | 442–610ms | felt instant per user; LazyVStack bounds per-swap work to visible row count |

### Investigation infrastructure
Console-streamed device logs via `xcrun devicectl device process launch --console --terminate-existing --device <udid> <bundle-id>`. Captured stdout to `/tmp/iburn-console.log`, grepped for `[perf]` lines. Cleaner than Xcode console-window juggling, gives the same data.

DEBUG-gated `print`-based timing helper (`PerfTimer`) was used during diagnosis and removed before commit (along with all `[perf]` call sites). Easy to re-introduce if perf issues recur.

## Context Preservation

### Debugging incidents
1. **First attempt at the fix** added `.id(viewModel.selectedDay)` to the List. Measured worse (509-659ms vs 442-610ms baseline) — teardown-recreate isn't cheaper than diff at this row count. Reverted.
2. **Bucket regression** (1306ms) was initially mysterious — same algorithm as the 22ms run in tests. Root cause: `Calendar.startOfDay`/`component` are not free on device under thermal load, especially when called per row in a tight loop on the GRDB callback thread.
3. **Metadata feedback loop** was a regression from round 1 — adding `ObjectMetadata.all()` to tracked regions (to make favorite toggles re-emit the list) interacted badly with the always-on `ensureMetadata` Task in `observeListRows`. The fix preserves favorite-toggle re-emission while skipping the bulk write.

### Why SwiftUI's `List` is slow at this scale
`List` (backed by `UITableView` under the hood, but the SwiftUI shim does additional bookkeeping) pre-processes all row identities on diff/recreate. For ~1500 rows per day this is ~400-600ms even though only ~5 rows are visible. `LazyVStack` does not have this bookkeeping — it materializes views as they enter the viewport. Trade-off is losing some List affordances (separators, swipe actions, table-style cell reuse), but the row already had `Divider()` styling and no swipe actions.

## Expected Outcomes

- Day-tab switching feels instant on real devices.
- Initial load is bounded by a single JOIN (~220ms on BigPhone 17).
- All 136 PlayaDB tests pass; 4 `EventListBucketObservationTests` continue to cover the observation behavior unchanged.

## Cross-References

- Round 1 doc: `Docs/2026-05-16-event-list-day-tab-perf.md` (DB layer)
- Plan file: `~/.claude/plans/okay-i-want-to-tingly-bee.md` (updated with round 2 strategy)
