# 2026-05-30 — Nearby Card on the Main Map

## High-Level Plan

### Problem / Need
The main map (`MainMapViewController`) shows pins but has no glanceable "what is right
here next to me" affordance. We want a compact, swipeable card pinned near the bottom of
the map that appears when the user is physically near art/camps/events, opens detail on tap,
favorites items, plays audio tours where present, and minimizes into a badged FAB with a
Liquid Glass morph.

### Solution Overview
A SwiftUI card hosted as a **proper child view controller** of the UIKit map (added via
`addChild`/`didMove(toParent:)`, not by extracting the inner `UIView`). It reuses the app's
existing data layer (data providers, `NearbyItem`, `RowAssetsLoader`, `AudioTourButton`,
`DetailViewControllerFactory`, `CoreLocationProvider`) — only the UI is new.

### Decisions (from user)
- **Proximity radius**: ~100 m (tight, "what's right here").
- **Types**: any object with GPS → art, camps, events. Mutant vehicles excluded (no GPS).
- **Card content**: image, title, one-line description, event timing, audio play button
  (audio-tour art only), and a favorite heart. Minimal.
- **Deployment target is iOS 16.6** → iOS 26 Liquid Glass APIs gated behind
  `#if canImport(FoundationModels)` + `if #available(iOS 26.0, *)`, with a
  `.ultraThinMaterial` + `matchedGeometryEffect` fallback (mirrors the codebase's existing
  iOS-26 gating pattern in `DependencyContainer.makeAIGuideViewModel`).

### Prerequisite (done)
Rebased the worktree branch `claude/fervent-knuth-adf76a` onto `ai-event-summary`
(fast-forward to `a455b2e` — "PlayaDB: index event region queries with a spatio-temporal
R*Tree"). This makes `EventFilter(region:)` queries R*Tree-backed (fast + correct: events
hosted by in-region camps now return). No public API change; the card just builds on it.

This card is **separate** from the planned "merge Nearby + Right Now" work
(`~/.claude/plans/what-were-we-up-zippy-dongarra.md`, Phase B). It reuses the same providers
and `NearbyItem` so the two stay consistent.

## Technical Details

### Files created (under `iBurn/Map/NearbyCard/` — Xcode 16 synchronized group, auto-included)
- `NearbyCardViewModel.swift` — `@MainActor ObservableObject`. Observes
  `Art/Camp/EventDataProvider.observeObjects(filter:)` over a ~100 m region + consumes
  `CoreLocationProvider.locationStream`. Emits a flat, ordered `[NearbyItem]`:
  - Events first (happening now / starting soon at `now`, by start time), then art + camps
    merged by distance; gated to `nearbyRadius` (100 m), de-duped by id, capped to 12.
  - Ordering extracted into pure `static func orderedItems(...)` for unit testing.
  - `selectedID` tracked by `NearbyItem.id` (not index) and preserved across rebuilds so
    location ticks don't yank the user mid-swipe; `isMinimized`; `now` refresh timer (30 s).
  - Region recenters only after the user moves ≥ 25 m; small moves just re-sort/re-gate.
- `NearbyCardView.swift` — paged card (`TabView` `.page` style, custom dots), compact
  `NearbyCardContentView` (thumbnail via `RowAssetsLoader`, 1-line title/description, event
  timing via `EventObjectOccurrence.timeDescription(now:)`, heart, `AudioTourButton` when
  `assets.audioURL != nil`), minimize button, badged FAB. `GlassSurface` modifier applies
  `.glassEffect(.regular.interactive(), …)` + shared `.glassEffectID("nearbyCard", …)` in a
  `GlassEffectContainer` on iOS 26 (morph between card and FAB), else material + matched
  geometry. Stable `cardWidth = min(380, screen − 32)`.
- `NearbyCardHostingController.swift` — `UIHostingController<NearbyCardView>`, owns the VM,
  `view.backgroundColor = .clear` + `sizingOptions = [.intrinsicContentSize]` (hosting view
  hugs the card/FAB, so the rest of the map stays interactive), pushes
  `DetailViewControllerFactory.create(with: subject, playaDB:)` on tap.

### Files modified
- `iBurn/DependencyContainer.swift` — added `makeNearbyCardViewModel()`.
- `iBurn/MainMapViewController.swift` — store `dependencies`, add `setupNearbyCard()` which
  `addChild`s the hosting controller bottom-centered (`autoAlignAxis(.vertical)` +
  `autoPinEdge(toSuperviewMargin: .bottom)` −12) and calls `didMove(toParent:)`.

### Tests
- `iBurnTests/NearbyCardViewModelTests.swift` — 7 tests against `orderedItems(...)`:
  events-first (even when farther), radius exclusion, art/camp distance sort, ended-event
  exclusion, dedup by id, cap to maxItems, drop no-GPS objects. Uses real PlayaDB model
  inits (no DB), `@MainActor`, no force-unwraps.

## Outcomes / Verification
- `xcodebuild build` (iBurn, iPhone 17 Pro Max, OS 26.2): **0 errors, 0 warnings** — the
  Liquid Glass path compiles against the iOS 26.2 SDK.
- `xcodebuild test -only-testing:iBurnTests/NearbyCardViewModelTests`: **7 passed, 0 failed**.
- Note: SPM resolution requires network, so builds were run with the command sandbox
  disabled.

### Not yet done
- On-device/simulator visual confirmation of the card + glass morph. Location data is
  **embargoed until gates open** (current date 2026-05-30), so art/camp coordinates are
  withheld and a quick simulator run likely surfaces no nearby objects. Visual verification
  needs un-embargoed/dev data + a simulated GPS fix inside Black Rock City.

### Possible follow-ups
- Pause the VM's location polling / refresh timer when the map tab isn't visible (battery).
- Minor: on narrow screens the centered card can slightly overlap the (currently
  non-functional) bottom-left `SidebarButtonsView`.
