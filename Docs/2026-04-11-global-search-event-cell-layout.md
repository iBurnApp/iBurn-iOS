# Unify All List Rows Into a Single ObjectRowView

## Problem
The app had three separate row view implementations:
- `ObjectRowView` -- layout only (thumbnail, title, description, subtitles, heart). Only consumed by `MediaObjectRowView`.
- `MediaObjectRowView` -- wraps `ObjectRowView`, adds `RowAssetsLoader` for thumbnail/color loading. Used for art/camp/MV.
- `EventRowView` -- completely different layout for events (75x75, heart on left, host info row, color-coded status).

This created visual inconsistency -- events looked different from everything else in search, favorites, nearby, and recently viewed.

## Solution
Merged `ObjectRowView` + `MediaObjectRowView` into a single `ObjectRowView` that handles thumbnail loading and all object types. Deleted both `MediaObjectRowView` and `EventRowView`.

Key design decisions:
- **`thumbnailObjectID` parameter**: Events pass the host camp/art UID for thumbnail lookup instead of the event's own UID
- **Shared `timeDescription(now:)`**: Dynamic event time formatting moved to shared extension on `EventObjectOccurrence` in `DisplayableObject.swift`
- **Event type emoji in actions slot**: Displayed at trailing edge of title row
- **Host info dropped from row**: Host camp thumbnail provides visual hint; full host info on detail screen

## Files Modified

| File | Change |
|------|--------|
| `iBurn/ListView/ObjectRowView.swift` | Rewritten: merged in `MediaObjectRowView`'s `RowAssetsLoader`, added `thumbnailObjectID`, default params |
| `iBurn/ListView/DisplayableObject.swift` | Added `EventObjectOccurrence.timeDescription(now:)` and `defaultTimeText` |
| `iBurn/ListView/GlobalSearchView.swift` | `MediaObjectRowView` -> `ObjectRowView`, removed private time extension |
| `iBurn/ListView/EventListView.swift` | `EventRowView` -> `ObjectRowView` with `thumbnailObjectID` and `timeDescription` |
| `iBurn/ListView/FavoritesView.swift` | Both `MediaObjectRowView` and `EventRowView` -> `ObjectRowView` |
| `iBurn/ListView/NearbyView.swift` | Both `MediaObjectRowView` and `EventRowView` -> `ObjectRowView` |
| `iBurn/ListView/RecentlyViewedView.swift` | Both `MediaObjectRowView` and `EventRowView` -> `ObjectRowView` |
| `iBurn/ListView/ArtListView.swift` | `MediaObjectRowView` -> `ObjectRowView` |
| `iBurn/ListView/CampListView.swift` | `MediaObjectRowView` -> `ObjectRowView` |
| `iBurn/ListView/MutantVehicleListView.swift` | `MediaObjectRowView` -> `ObjectRowView` |
| `iBurn/AISearch/AIAssistantView.swift` | `MediaObjectRowView` -> `ObjectRowView` |
| `iBurn/AISearch/WorkflowDetailView.swift` | `MediaObjectRowView` -> `ObjectRowView` |
| `iBurn/Detail/Controllers/PlayaHostedEventsViewController.swift` | `EventRowView` -> `ObjectRowView` |
| `iBurn/ListView/RecentlyViewedViewModel.swift` | Comment update |
| `iBurn/ListView/GlobalSearchViewModel.swift` | Comment update |

## Files Deleted

| File | Reason |
|------|--------|
| `iBurn/ListView/MediaObjectRowView.swift` | Merged into `ObjectRowView` |
| `iBurn/ListView/EventRowView.swift` | Replaced by `ObjectRowView` everywhere |

## Verification
- Build: 0 errors, all warnings pre-existing
- iBurnTests: 0 failures
- PlayaDB tests: 110 passed
- Grep: zero references to `EventRowView` or `MediaObjectRowView` in Swift files
