# 2026-08-20 — Floating action button missing at cold launch

## Fix: favorites FAB hidden at cold launch

### Problem

User report against the live App Store build (2026.0): on cold launch the favorites
floating action button (the glass heart above the search circle) was missing from the
initially-shown Map tab. Switching to another tab and back made it appear, and it stayed
for the rest of the session.

### Root cause — a zero-geometry race

The FAB is a single app-wide view on `TabController.view` (`iBurn/TabController.swift`,
`iBurn/Tabs/FloatingActionButton.swift`), installed from
`configure(withRootViewControllers:)`. `BRCAppDelegate.m` calls that (~line 288) *before*
it assigns `window.rootViewController` (~line 399). At that moment the controller's view
has no window and `view.bounds` and `tabBar.frame` are both `.zero`, so the old visibility
math

```swift
let barIsOffscreen = tabBarFrameInView.map { $0.minY >= view.bounds.height } ?? false
```

evaluated `0 >= 0` → `true` → "the bar has slid off the bottom" → `isHidden = true`.
`updateFloatingButtonPlacement()` mis-measured the same way: `tabBarIsDockedAtBottom`
compared `0 > 0` → `false`, so `.bottomSafeArea` was committed (and cached) as if it had
been measured.

Normally the first real layout pass (`viewDidLayoutSubviews`) re-ran both and corrected
everything before anything was drawn, which is why this never showed in testing. On a
slower device, with the launch landing mid tab-bar animation, no further layout pass
arrived for the initial tab — leaving the button hidden until a tab switch forced one.

Same family as commit `7557adda` (iPad launch crash: measuring the tab bar before it is
meaningful), whose out-of-hierarchy safety is preserved here.

### Fix

1. **Pure, testable visibility rule** — new `FloatingActionButtonBarVisibility.isHidden(
   tabBarHidden:tabBarAlpha:barFrameMinY:viewHeight:)` in
   `iBurn/Tabs/FloatingActionButton.swift`, parallel to
   `FloatingActionButtonPlacement.placement(...)`. A view with no geometry
   (`viewHeight == 0`, or no convertible bar frame) is *unknown*, not *off screen*: the
   frame test is skipped and the button stays visible pending a real layout pass.
   `isHidden`/`alpha == 0` are explicit states rather than measurements, so they still hide
   the button whatever the geometry says. The config rule
   (`FloatingActionButtonVisibility.isVisible`) still governs whether the button exists at
   all — that check is unchanged and runs first.
2. **`TabController.updateFloatingButtonVisibility()`** is now a thin caller: it computes
   `geometryIsKnown` (`view.window != nil && view.bounds.height > 0`) and passes
   `nil`/`0` for the frame inputs when it is false.
3. **Placement defers instead of guessing** — `updateFloatingButtonPlacement()` returns
   early when geometry is unknown. The button still needs *some* vertical constraint before
   the first layout pass, so on first install it takes the always-legal `.bottomSafeArea`
   anchor via `applyPlacement(_:record:)` with `record: false`, which leaves
   `floatingButtonPlacement` nil so the first pass that can measure re-decides rather than
   finding a cached answer that matches.
4. **Belt and braces** — `TabController.viewDidAppear(_:)` does `view.setNeedsLayout()` and
   one authoritative `updateFloatingButtonPlacement()` /
   `updateFloatingButtonVisibility()` / `alignFloatingButtonWithSearchTab()` pass. Whatever
   an early geometry-less pass decided, a real-geometry pass always follows. No timers, no
   `asyncAfter`.

### Files

- `iBurn/Tabs/FloatingActionButton.swift` — added `FloatingActionButtonBarVisibility`.
- `iBurn/TabController.swift` — `viewDidAppear(_:)` override; `geometryIsKnown`;
  `applyPlacement(_:record:)` extracted from `updateFloatingButtonPlacement()`;
  `updateFloatingButtonVisibility()` rewritten as a caller of the pure rule.
- `iBurnTests/FloatingActionButtonPlacementTests.swift` — new
  `FloatingActionButtonBarVisibilityTests`.

### Tests

Six new cases covering the rule: the 0/0 cold-launch case must **not** hide; an
unconvertible (`nil`) bar frame must not hide; a bar genuinely at/below the view's bottom
edge (`minY >= height`, `height > 0`) hides; a normally docked bar shows; `isHidden` and
`alpha == 0` hide regardless of geometry.

```
xcodebuild test -workspace iBurn.xcworkspace -scheme iBurnTests \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.5,arch=arm64'
→ 615 passed, 0 failed
```

### Simulator validation

`build_run_sim` on iPhone 17 Pro Max (iOS 26.5), cold launch, no interaction before the
screenshot: the glass heart FAB is present above the search circle on the initial Map tab.
Switching to Events and back to Map leaves it in the identical position. AX snapshot lists
`floatingActionButton` on both passes.

Caveat: this reproduces the report's conditions only approximately — the original race was
device-timing-dependent (slow launch, mid tab-bar animation), and on a fast simulator the
old code self-corrected on the first layout pass anyway. Treat the screenshots as
regression sanity, not proof; the guarantee comes from the pure rule (unit-tested) plus the
`viewDidAppear` re-evaluation.

### Cross-references

- `7557adda` — iPad launch crash from constraining to an out-of-hierarchy tab bar; same
  "measured the tab bar too early" family, and its hierarchy guard is untouched here.

---

## Fix: reminders prompt on unfavorite / prompt spam

### Problem

On the live App Store build, un-favoriting an event from the SwiftUI Favorites list popped
the PermissionScope "Reminders / Don't you want reminders?" modal **every time**, tapping
"Close" never suppressed it, and its copy ("⚠️ Favorited events are added to your device's
default calendar ⚠️") is nonsense in the context of *removing* a favorite.

### Root causes

1. `EventCalendarServiceImpl.performReconcile` (`iBurn/Calendar/EventCalendarService.swift`)
   called `eventStore.ensureAccess()` unconditionally. `isFavorite` was used only as a
   coalescing key, never to gate prompting, so a removal pass prompted exactly like an
   adding pass. `EKEventStoreProvider.ensureAccess` prompts whenever
   `EKAuthorizationStatus == .notDetermined`.
2. PermissionScope's "Close" button calls `cancel()` and never asks EventKit for anything,
   so the status stays `.notDetermined` forever → every subsequent reconcile prompted
   again. There was no app-level "already asked" state anywhere.
3. Legacy parity gaps: `BRCEventObject +eventStore` prompted on `.notDetermined` and was
   called by *both* `scheduleNotification:` and `cancelNotification:`; and
   `BRCDetailViewController didTapFavorite:` called `refreshCalendarEntry:` with no
   feature-flag check, unlike `DetailDataService`, which skips the Yap write when PlayaDB
   calendar sync owns the entries. Dormant today (`useSwiftUIDetailView` defaults true) but
   a live preference.

### Changes

- **`iBurn/Calendar/EventStoreProviding.swift`**
  - Protocol method is now `ensureAccess(promptIfNeeded: Bool) async -> Bool`, documented as
    "only adding passes may ask" plus a hard requirement that implementations pre-prompt at
    most once per app launch.
  - `EKEventStoreProvider` gained `promptLock` + `hasPrompted` and a `claimPrompt()` latch;
    it prompts only when `status == .notDetermined && promptIfNeeded && !hasPrompted`.
    In-memory only — a real iOS `.denied` never prompts anyway, so no persisted decline flag
    is needed.
- **`iBurn/Calendar/EventCalendarService.swift`**
  - `performReconcile` now passes `promptIfNeeded: isFavorite`; a removal pass with no
    access silently no-ops (nothing can be in the calendar unless access existed at write
    time; if access was revoked later we can't remove it anyway). Doc comment on the
    `isFavorite` parameter updated to say it now has this second job.
  - Added `@objc(BRCCalendarSync) final class CalendarSyncBridge` exposing
    `isPlayaDBSyncEnabled`, so ObjC can read the feature flag without duplicating its
    default.
- **`iBurn/BRCEventObject.m`**
  - `+eventStore` → `+eventStorePromptingIfNeeded:`. `scheduleNotification:` passes `YES`
    (the favoriting path keeps its prompt), `cancelNotification:` passes `NO`. Those two
    were the only callers (the method is file-private; not declared in the header).
- **`iBurn/BRCDetailViewController.m`**
  - `didTapFavorite:` now guards the `refreshCalendarEntry:` call with
    `!BRCCalendarSync.isPlayaDBSyncEnabled`, mirroring
    `DetailDataService.playaDBCalendarService`.

This also fixes the rapid favorite→unfavorite double-prompt: `reconcile` queues
opposite-intent passes sequentially and both could previously prompt.

### Tests

`iBurnTests/EventCalendarServiceTests.swift`: `SpyEventStore` now counts prompts
(`promptCount`) and models the provider contract — an undetermined status prompts only when
asked and only once per session. New/updated tests:

- `testUnfavoriteNeverPrompts` — unfavorite pass while `.notDetermined` → 0 prompts.
- `testPromptsOncePerSessionWhileUndetermined` — favorite → 1; unfavorite, re-favorite, and
  favorite a *different* event in the same session → still 1.
- `testDeniedNeverPrompts` — real `.denied` → 0 prompts in either direction.
- `testEKEventStoreProviderGatesOnAuthorization` — extended: repeat `ensureAccess` calls
  add no prompts.
- `testEKEventStoreProviderDoesNotPromptWithoutRequest` — a removal pass never prompts, even
  as the first call of a session.

```
xcodebuild test -workspace iBurn.xcworkspace -scheme iBurnTests \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.5,arch=arm64'
→ 619 passed, 0 failed (62.8s)
```
Full `iBurn` scheme build: 0 errors, 0 warnings.

### Simulator smoke test

Fresh install (simulator erased, so EventKit is `.notDetermined`). Onboarding was advanced
by **swiping past** the "Reminders" page rather than tapping "⏰ Continue with Notifications"
— that is how you keep calendar access undetermined for this test.

| Step | Result |
| --- | --- |
| Favorite "Booty Hour" from the Events list | Reminders modal appears **once** ✅ |
| Tap "Close" | Modal dismisses, list keeps the favorite ✅ |
| Unfavorite "Booty Hour" | **No modal** ✅ |
| Favorite "Drama Dump & Gift" (same session) | **No modal** ✅ |
| Unfavorite it from the Favorites sheet (the exact reported repro) | **No modal**, list falls back to "No favorites yet" ✅ |

### Follow-ups

- **PermissionScope / EventKit iOS 17 APIs** — the vendored submodule still calls the
  deprecated `requestAccessToEntityType:`; move to `requestFullAccessToEvents`. Also worth
  reconsidering the pre-prompt copy, which reads oddly outside the favoriting flow.
- **Watch favorites bypass `FavoriteSyncService`** — favorites made on the watch don't route
  through the calendar reconcile hook.
- **Stale `event_calendar_entries`** — when an occurrence's start time shifts across an
  import, the entry keyed by the old ISO start is orphaned in the calendar.
- **Legacy `didTapFavorite:` double-write** — the detail-screen guard added here resolves
  the calendar half of this for the `useSwiftUIDetailView = false` path; the remaining
  concern is the metadata write itself, which is still duplicated between the UIKit screen
  and the SwiftUI service.
