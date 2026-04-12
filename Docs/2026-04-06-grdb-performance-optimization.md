# GRDB Query Performance Optimization

## Problem Statement
PlayaDB queries are noticeably slower than the old YapDatabase. Root causes: N+1 query patterns, missing indexes, redundant fetches, and multiple write transactions where one suffices.

## Solution Overview
7 fixes targeting the highest-impact bottlenecks, all verified with a clean build.

## Changes Applied

### Fix 1: Batch `getFavorites()` (CRITICAL)
**File:** `PlayaDBImpl.swift`
- **Before:** N+1 — loops through favorite metadata with individual `fetchOne()` per object
- **After:** Groups metadata by type, batch-fetches each type with `IN` clause
- **Impact:** 101 queries → 5 queries for 100 favorites

### Fix 2: Batch `fetchRecentlyViewed()` (CRITICAL)
**File:** `PlayaDBImpl.swift`
- Same N+1 → batch pattern as Fix 1
- Preserves original ordering (most recently viewed first) via dictionary lookup

### Fix 3: Batch `fetchFavoriteEvents()` (CRITICAL)
**File:** `PlayaDBImpl.swift`
- **Before:** Individual `fetchOne()` per favorite event ID
- **After:** Single batch `IN` query for all favorite events
- **Impact:** N+1 → 3 queries

### Fix 4: Add Missing Indexes (HIGH)
**File:** `PlayaDBImpl.swift` `setupDatabase()`
- `idx_event_hosted_by_camp` — camp crawl, event-at-art queries
- `idx_event_located_at_art` — event-at-art queries
- `idx_object_metadata_type_favorite` — composite for getFavorites
- `idx_event_occurrences_event_start` — composite for time-range queries
- `idx_object_metadata_last_viewed` — fetchRecentlyViewed

### Fix 5: Fix Event Observation Double-Fetch (HIGH)
**File:** `PlayaDBImpl.swift`
- Removed `.including(all: EventObject.occurrences)` from event observation
- The eager-load wasn't decoded (GRDB requires explicit decoding), then occurrences were re-fetched in the loop
- Simple `EventObject.fetchAll(db)` + per-event occurrence fetch is correct and avoids redundant JOIN

### Fix 6: Batch `ensureMetadata` Calls (MEDIUM)
**File:** `PlayaDBImpl.swift`
- Added `ensureMetadata(for: [(DataObjectType, [String])])` batch variant
- Single-type variant delegates to batch
- Updated `fetchObjects(in:)` and `searchObjects()` to use batch (3-4 write transactions → 1)

### Fix 7: Add `fetchObjects(byUIDs:)` Batch Method (MEDIUM)
**Files:** `PlayaDB.swift` protocol, `PlayaDBImpl.swift`, `AIGuideViewModel.swift`, `AIAssistantViewModel.swift`, `ChatViewModel.swift`
- New protocol method: `fetchObjects(byUIDs:) -> [any DataObject]`
- 4 queries total (one per type) regardless of UID count
- All three `resolveUIDs()` implementations updated to use batch fetch
- **Impact:** ~40 queries → 4 queries for 10 UIDs

## Files Modified

| File | Changes |
|------|---------|
| `Packages/PlayaDB/Sources/PlayaDB/PlayaDBImpl.swift` | Fixes 1-6: indexes, batch getFavorites/fetchRecentlyViewed/fetchFavoriteEvents/ensureMetadata, event observation, fetchObjects(byUIDs:) |
| `Packages/PlayaDB/Sources/PlayaDB/PlayaDB.swift` | Fix 7: added `fetchObjects(byUIDs:)` to protocol |
| `iBurn/AISearch/AIGuideViewModel.swift` | Fix 7: batch resolveUIDs |
| `iBurn/AISearch/AIAssistantViewModel.swift` | Fix 7: batch resolveUIDs |
| `iBurn/AISearch/ChatViewModel.swift` | Fix 7: batch resolveUIDs |

## Fix 8: Batch Event Occurrence Fetching (CRITICAL)
**File:** `PlayaDBImpl.swift`

Two new private helpers eliminate N+1 occurrence/event lookups across **10 call sites**:

### Helper A: `eventObjectOccurrences(for events: [EventObject], db:)`
- Given events, batch-fetches ALL their occurrences with a single `IN` query on `event_id`
- Joins in Swift via dictionary lookup
- **Replaces:** per-event `event.occurrences.fetchAll(db)` loops (5 sites)

### Helper B: `eventObjectOccurrences(for occurrences: [EventOccurrence], db:)`
- Given occurrences, batch-fetches ALL parent events with a single `IN` query on `uid`
- Joins in Swift via dictionary lookup
- **Replaces:** per-occurrence `occurrence.event.fetchOne(db)` calls (5 sites)

### Sites Updated
| Method | Pattern | Before | After |
|--------|---------|--------|-------|
| `fetchEvents()` | A | N+1 events→occurrences | 2 queries |
| `fetchEvents(hostedByCampUID:)` | A | N+1 | 2 queries |
| `fetchEvents(locatedAtArtUID:)` | A | N+1 | 2 queries |
| `fetchFavoriteEvents()` | A | N+1 | 2 queries |
| Event observation (ValueObservation) | A | N+1 per fire | 2 queries |
| `fetchEvents(on:)` | B | N+1 occurrences→events | 2 queries |
| `fetchEvents(from:to:)` | B | N+1 | 2 queries |
| `fetchCurrentEvents()` | B | N+1 | 2 queries |
| `fetchUpcomingEvents()` | B | N+1 | 2 queries |
| `eventObjectOccurrences(filter:db:)` | B | N+1 | 2 queries |

Also removed unnecessary `.including(required: EventOccurrence.event)` from occurrence queries — the eager-load wasn't decoded by GRDB with the current model design.

## Verification
- Build: `xcodebuild ... 2>&1 | xcsift -f toon -w` — **PASS** (0 errors, 0 warnings)
- No new warnings in changed code

## Recently Viewed Feature

### New Files
| File | Purpose |
|------|---------|
| `iBurn/ListView/RecentlyViewedItem.swift` | `RecentlyViewedItem` enum, `ViewDates` struct, `RecentlyViewedTypeFilter`, `RecentlyViewedSortOrder`, `RecentlyViewedSection` |
| `iBurn/ListView/RecentlyViewedViewModel.swift` | VM with load, search, sort (recent/distance), remove single, clear all, favorites, map annotations |
| `iBurn/ListView/RecentlyViewedView.swift` | SwiftUI list with type filter segments, sort picker, swipe-to-remove, clear all confirmation |
| `iBurn/ListView/RecentlyViewedHostingController.swift` | UIKit bridge with detail navigation and map support |

### Modified Files
| File | Changes |
|------|---------|
| `Packages/PlayaDB/Sources/PlayaDB/PlayaDB.swift` | Added `fetchRecentlyViewedWithDates`, `clearLastViewed`, `clearAllRecentlyViewed` |
| `Packages/PlayaDB/Sources/PlayaDB/PlayaDBImpl.swift` | Implemented new protocol methods, `first_viewed` column + migration, `setLastViewed` sets `firstViewed` on first view |
| `Packages/PlayaDB/Sources/PlayaDB/Models/ObjectMetadata.swift` | Added `firstViewed: Date?` field and `Columns.firstViewed` |
| `iBurn/MoreViewController.swift` | Added "Recently Viewed" row with clock icon |
| `iBurn/Detail/Models/DetailCellType.swift` | Added `.viewHistory(firstViewed:lastViewed:)` cell type |
| `iBurn/Detail/Views/DetailView.swift` | Added `DetailViewHistoryCell` showing first/last viewed dates |
| `iBurn/Detail/ViewModels/DetailViewModel.swift` | Added `firstViewed`/`lastViewed` published properties, loaded from metadata |

### Features
- Filterable by type (All/Art/Camps/Events/Vehicles)
- Sortable by most recent or nearest distance
- Search within history
- Swipe to remove individual items
- Clear All with confirmation dialog
- Map view of all recently viewed items
- First viewed / last viewed dates shown on detail screens
- `first_viewed` tracked on first view, `last_viewed` updated on every view
- Database migration adds `first_viewed` column to existing databases

## Skipped (Low Priority)
- R-Tree in filtered region queries — existing GPS indexes sufficient for BRC dataset size
- FTS5 token vs phrase matching — already fixed the crash, phrase matching works fine
