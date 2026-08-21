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
