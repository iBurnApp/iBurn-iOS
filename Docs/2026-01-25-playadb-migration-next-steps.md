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
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/ObjectListViewModel.swift` (updated; now uses PlayaDB favorites only)
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/ArtListViewModel.swift` (updated; now a typealias)
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/CampListViewModel.swift` (updated; now a typealias)
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/ArtDataProvider.swift` (updated; `isDatabaseSeeded()` helper)
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/CampDataProvider.swift` (updated; `isDatabaseSeeded()` helper)
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/DependencyContainer.swift` (updated; builds list VMs via shared model)
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/ArtListView.swift` (updated previews; avoids Yap usage)
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/CampListView.swift` (updated previews; avoids Yap usage)

**Favorites (PlayaDB-only)**

The SwiftUI Art/Camp lists no longer read or write favorites via Yap metadata. Favorites now:
1) are written via `PlayaDB.toggleFavorite(...)`
2) are kept up-to-date for heart icon display by running a second PlayaDB observation with `onlyFavorites = true` and maintaining `favoriteIDs` in the view model.

Files:
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/ObjectListViewModel.swift`

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
  - Favorites IDs come from the dedicated favorites observation
  - Favorite toggling calls provider and updates local `favoriteIDs`

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

Audio tour button (SwiftUI Art list):
- Implemented without adding PlayaDB columns. The source of truth is the filesystem/bundled media:
  - `BRCMediaDownloader.localMediaURL("\(uid).m4a")` determines if a row has audio.
- Refactored `BRCAudioPlayer` to support a shared underlying representation (`BRCAudioTourTrack`), keeping legacy `[BRCArtObject]` entry points for backward compatibility.
- SwiftUI button matches legacy emoji affordance (“🔈 ▶️” / “🔊 ⏸”) and listens for `BRCAudioPlayerChangeNotification` to stay in sync.

Favorites (SwiftUI lists):
- Removed Yap/legacy favorites dependency from `ObjectListViewModel`.
- Favorites are now sourced from PlayaDB only; the view model maintains `favoriteIDs` via a second PlayaDB observation (`onlyFavorites = true`) to keep heart icons in sync.

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

---

## Next Plan: Remove LegacyDataStore From SwiftUI List Navigation (Art/Camps)

### Goal
- SwiftUI Art/Camp lists should navigate (detail + map) without using YapDatabase-backed `LegacyDataStore` at all.
- Allowed dependencies: PlayaDB (GRDB) + `BRCMediaDownloader` (filesystem/bundled media). Audio continues to use `BRCAudioPlayer` (now supports `BRCAudioTourTrack`).

### Plan (Incremental)
1) **Detail flow (PlayaDB-only)**
   - Add new SwiftUI detail views for `PlayaDB.ArtObject` and `PlayaDB.CampObject`.
   - Back them with a small view model that:
     - reads `ObjectMetadata` via `PlayaDB.metadata(for:)`
     - toggles favorites via `PlayaDB.toggleFavorite(_:)`
     - loads thumbnail/audio URLs via `MediaAssetProviding` (`BRCMediaDownloader.localMediaURL`)
     - optionally supports notes + lastViewed (requires PlayaDB API additions below)

2) **Metadata write support**
   - Extend `Packages/PlayaDB` public API with explicit metadata update methods (notes + lastViewed) so the app can persist those without reaching into GRDB internals.
   - Add unit tests in `PlayaKitTests` or `iBurnTests` (whichever already hosts PlayaDB tests) that verify:
     - notes round-trip
     - lastViewed updates
     - updatedAt changes appropriately

3) **Map flow (PlayaDB-only)**
   - Implement a new annotation type (e.g. `PlayaObjectAnnotation`) that conforms to `MLNAnnotation` + `ImageAnnotation` and is built from PlayaDB objects (uid, type, coordinate, title/subtitle).
   - Enforce embargo via `BRCEmbargo.allowEmbargoedData()` (if embargoed, don’t show art/camp pins).

4) **Map callout -> Detail**
   - Update `MapViewAdapter` to:
     - render `PlayaObjectAnnotation` using `LabelAnnotationView` (same look as legacy)
     - route info-tap to the new detail flow via an injected closure/delegate (so we don’t call `DetailViewControllerFactory`).
   - Defer share QR action for Playa objects until we have a PlayaDB-compatible share payload.

5) **Replace LegacyDataStore usage**
   - Update:
     - `iBurn/ListView/ArtListHostingController.swift`
     - `iBurn/ListView/CampListHostingController.swift`
   - `onSelect`: push the new PlayaDB detail hosting controller.
   - `onShowMap`: build `PlayaObjectAnnotation`s from the current filtered items and push `MapListViewController(dataSource: StaticAnnotationDataSource(annotations: ...))`.

6) **Verification**
   - Verify on iOS 26.2 sim:
     - list -> detail works
     - list -> map works
     - map callout info -> detail works
     - favorites + notes persist via PlayaDB
     - embargo hides art/camp pins when locked
