# Visit List Implementation
Date: 2025-08-16

## Problem Statement
The visit status filtering ("Want to Visit", "Visited") was not working properly in several areas:
1. Map view - The filtering logic was inverted, only creating data sources when some filters were OFF instead of actively filtering when needed
2. Art and Camps list views - No visit status filtering capability at all
3. Favorites view - Didn't filter by visit status

## Solution Overview
Added a dedicated "Visit List" view accessible from the More screen that provides a unified interface for viewing and filtering items by visit status.

## Implementation Details

### 1. Created VisitListViewController
- New view controller at `iBurn/VisitListViewController.swift`
- Provides segmented control with three options: "Want to Visit", "Visited", "All"
- Inherits from UIViewController with custom ListCoordinator setup
- Switches between different YapDatabase views based on selected filter:
  - `wantToVisitObjectsViewName` - Shows items marked as want to visit
  - `visitedObjectsViewName` - Shows visited items
  - `dataObjectsViewName` - Shows all items

### 2. Updated MoreViewController
- Added new `visitList` case to `DetailViewsRow` enum
- Added "Visit List" row with bookmark icon to the detail views section
- Created `pushVisitListView()` method to navigate to the new view

### 3. Fixed Map Filtering Logic
- Updated `FilteredMapDataSource.swift` to always create visit status data sources
- Changed from conditional creation to always having references available
- This allows proper filtering regardless of which combination of filters is selected

## Key Changes

### Files Modified:
1. `iBurn/MoreViewController.swift` - Added Visit List menu item
2. `iBurn/FilteredMapDataSource.swift` - Fixed visit status filtering logic

### Files Created:
1. `iBurn/VisitListViewController.swift` - New unified visit list view

## Technical Details

### Database Views Used:
- `BRCDatabaseManager.visitedObjectsViewName` - Filters to show only visited items
- `BRCDatabaseManager.wantToVisitObjectsViewName` - Filters to show only want to visit items
- `BRCDatabaseManager.dataObjectsViewName` - Shows all data objects (art, camps, events)

### UI Components:
- UISegmentedControl for filter selection
- Grouped table view style for consistent appearance
- Auto-refresh timer (30 seconds) to update when visit status changes
- Search and map buttons integrated

## Testing Notes
- Build succeeded with all changes
- The Visit List appears in the More screen menu
- Segmented control switches between different visit status filters
- Map filtering now properly respects visit status settings

## Future Enhancements
- Could add sub-filtering by object type (Art/Camps/Events) within the visit list
- Could add visit status filtering to individual Art and Camps list views
- Could add statistics showing count of items in each category

## Related Work
This builds on the visit tracking feature implemented earlier, providing a dedicated interface for managing and viewing items by visit status.