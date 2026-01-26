# PlayaDB Migration Next Steps (2026-01-25)

## High-Level Plan
- **Problem Statement**: Continue the ongoing PlayaDB (GRDB) migration after completing the SwiftUI Art/Camp list MVP work.
- **Solution Overview**: Pick the next vertical slice that reduces legacy YapDatabase surface area while keeping feature flags for safe rollout. The most natural next slice is Events (day-based list + time queries), followed by favorites sync hardening and search.
- **Key Changes (Proposed)**:
  - Add an Events list stack backed by `Packages/PlayaDB` `EventObjectOccurrence` queries.
  - Extend PlayaDB filtering/observation to support day/date-range event queries used by the legacy Event list UI.
  - Keep legacy detail/map flows bridged until corresponding GRDB-backed equivalents exist.

## Technical Details

## 2026-01-25 Session Progress (Art/Camps Lists First)

User direction: finish Art/Camp list migration before tackling Events.

### Changes Implemented

**Shared list view model (no hierarchy) + loading gate**

Refactored the duplicated Art/Camp SwiftUI list view model logic into a single generic view model that is configured via closures (search matching + effective filter), avoiding a class inheritance tree.

Also added a loading gate so the lists show a spinner instead of immediately showing an empty state while PlayaDB seeding is still in progress (first observation emission can be empty before seed completes).

Files:
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/ObjectListViewModel.swift` (new; shared logic)
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/FavoritesFilterable.swift` (new; protocol + ArtFilter/CampFilter conformance)
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/LegacyFavoritesStoring.swift` (new; protocol for favorites only)
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/LegacyDataStore.swift` (updated; conforms to `LegacyFavoritesStoring`)
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/ArtListViewModel.swift` (updated; now a typealias)
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/CampListViewModel.swift` (updated; now a typealias)
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/ArtDataProvider.swift` (updated; `isDatabaseSeeded()` helper)
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/CampDataProvider.swift` (updated; `isDatabaseSeeded()` helper)
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/DependencyContainer.swift` (updated; builds list VMs via shared model)
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/ArtListView.swift` (updated previews; avoids Yap usage)
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/CampListView.swift` (updated previews; avoids Yap usage)

**Favorites toggle sync (legacy -> PlayaDB)**

During migration the SwiftUI list UI reads favorites from legacy Yap metadata (`LegacyDataStore.favoriteIDs(...)`). PlayaDB favorites can drift, so toggling now:
1) derives the desired state from UI
2) optimistically updates local `favoriteIDs` for responsiveness
3) writes desired state to legacy metadata
4) reconciles PlayaDB to match (only toggling if needed)

Files:
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/ArtListViewModel.swift`
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/CampListViewModel.swift`

### Build / Tests (iOS 26.2 simulator)

Build (succeeded):
```bash
xcodebuild -workspace iBurn.xcworkspace -scheme iBurn -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.2,arch=arm64' -quiet
```

iBurnTests (succeeded):
```bash
xcodebuild test -workspace iBurn.xcworkspace -scheme iBurnTests -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.2,arch=arm64' -quiet
```

### Unit Tests Added

Added focused tests for the new shared list view model:
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurnTests/ObjectListViewModelTests.swift`
  - Loading gate behavior (empty first emission remains loading until seeded)
  - Non-empty first emission clears loading
  - Favorites-only filtering is client-side while observation receives `onlyFavorites = false`
  - Favorite toggling writes legacy and reconciles the provider

### List Cell Parity Progress

**Thumbnails + image-colors theming (SwiftUI lists, without YapDatabase objects)**

Goal: replicate the legacy `ArtImageCell` behavior (local cached thumbnail image + optional per-row color theming) while targeting PlayaDB models, not YapDatabase objects.

Implementation:
- Local cached thumbnail lookup uses the existing media cache naming scheme (`<uid>.jpg`) via `BRCMediaDownloader.localMediaURL`, protocolized behind `MediaAssetProviding`.
- Image-derived colors are computed on-demand from the local thumbnail using `UIImageColors` and cached in-memory (no new DB table for local assets).

Files:
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/MediaAssetProviding.swift` (new)
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/RowAssetsLoader.swift` (new)
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/MediaObjectRowView.swift` (new)
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/ObjectRowView.swift` (updated; supports thumbnail + optional colors override)
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/ArtListView.swift` (updated; uses `MediaObjectRowView`)
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/CampListView.swift` (updated; uses `MediaObjectRowView`)

### Current State (from existing Docs)
- GRDB-backed SwiftUI Art + Camp lists exist behind DEBUG feature flag `Preferences.FeatureFlags.useSwiftUILists`.
- Data seeding exists via `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/PlayaDBSeeder.swift` (imports bundled JSON into PlayaDB when `getUpdateInfo()` is empty).
- Legacy bridging exists via `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/LegacyDataStore.swift` (favorites + detail + map annotations via YapDatabase).

Primary reference doc:
- `/Users/chrisbal/Documents/Code/iBurn-iOS/Docs/2026-01-10-grdb-list-view-mvp.md`

Related historical references:
- `/Users/chrisbal/Documents/Code/iBurn-iOS/Docs/2025-08-03-playadb-event-occurrence-redesign.md`
- `/Users/chrisbal/Documents/Code/iBurn-iOS/Docs/2025-10-25-swiftui-list-views-implementation.md`

### Repo Status Snapshot
- Branch: `playadb-migration`
- Working tree: had local changes after updating favorite toggling sync (see section above)

## 2026-01-25 Session Continued (SwiftUI Art/Camps Cell Parity)

### Problem Statement
- SwiftUI Art/Camp list rows (PlayaDB-backed) still look/behave “MVP” compared to the legacy UIKit list cells (notably thumbnails, spacing, distance placement, clipping, and flicker/jank while assets/colors load).

### Legacy Reference (UIKit)
File: `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ArtImageCell.xib`

Key layout facts:
- Thumbnail image view is **100x100** with a **1:1 aspect ratio constraint** and `scaleAspectFill`.
- Thumbnail + description live in a stack view with **spacing = 8**.
- Subtitle (walk/bike time) label is positioned **below the thumbnail stack view** with **top spacing = 8**.

Relevant XIB snippet:
```xml
<stackView ... spacing="8" ...>
  <imageView ... contentMode="scaleAspectFill" ...>
    <constraint firstAttribute="height" constant="100" .../>
    <constraint firstAttribute="width" constant="100" .../>
    <constraint firstAttribute="width" secondItem="..." secondAttribute="height" multiplier="1:1" .../>
  </imageView>
  <label ... id="descriptionLabel" .../>
</stackView>
<label ... id="subtitleLabel" .../>
```

### Implementation Notes (SwiftUI)

Primary file updated:
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/ObjectRowView.swift`

Changes:
- Reserve a fixed 100x100 thumbnail slot so the row doesn’t reflow when the image arrives.
- Fix thumbnail clipping so it cannot overflow into adjacent content.
- Align the distance/walk/bike subtitle under the thumbnail by giving it a fixed width of 100.
- Match legacy label coloring intent:
  - Description uses `detailColor`
  - Right subtitle uses `secondaryColor`
- Represent missing thumbnails with `UIImage? == nil` (no separate `isMissingThumbnail` boolean).

Media lookup (no YapDB objects; reuse legacy disk cache):
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/MediaAssetProviding.swift` (protocol; default uses `BRCMediaDownloader.localMediaURL("\(uid).jpg")`)
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/RowAssetsLoader.swift` (sync thumbnail load, async colors, in-memory caches)
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/MediaObjectRowView.swift` (row wrapper that owns `RowAssetsLoader`)

### Build / Tests (iOS 26.2 simulator)

Build (succeeded):
```bash
xcodebuild -workspace iBurn.xcworkspace -scheme iBurn -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.2,arch=arm64' -quiet
```

iBurnTests (succeeded):
```bash
xcodebuild test -workspace iBurn.xcworkspace -scheme iBurnTests -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.2,arch=arm64' -quiet
```

## Context Preservation
- The next missing GRDB migration slice for parity is Events; existing PlayaDB already exposes:
  - `/Users/chrisbal/Documents/Code/iBurn-iOS/Packages/PlayaDB/Sources/PlayaDB/PlayaDB.swift` event APIs (`fetchEvents(on:)`, `fetchCurrentEvents`, etc.)
  - `/Users/chrisbal/Documents/Code/iBurn-iOS/Packages/PlayaDB/Sources/PlayaDB/Filters/EventFilter.swift` (time-based filters, but no explicit "day" filter for observation).
- The legacy event UI entry point is `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/EventListViewController.swift`.

## Cross-References
- See `/Users/chrisbal/Documents/Code/iBurn-iOS/Docs/2026-01-10-grdb-list-view-mvp.md` for the Art/Camp list MVP wiring and seeding approach.

## Expected Outcomes (Once Next Slice Lands)
- Users can browse Events using PlayaDB data (including correct cross-midnight occurrences) behind a feature flag.
- Tapping an event can still route to the existing legacy detail flow until event detail is migrated.
- The app continues to build and `xcodebuild test -scheme iBurnTests` continues to pass on simulator.
