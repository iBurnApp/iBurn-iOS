# Visit List Real-Time Updates Fix
Date: 2025-08-17

## Problem Statement
The Visit List view was not updating in real time when items were marked as visited or want to visit from the detail screen. The data was correctly persisted to the database, but the visit list view wasn't refreshing to show the changes immediately.

## Root Cause Analysis
The issue was at the YapDatabase layer. The `allObjectsGroupedByVisitStatusViewName` view groups objects by visit status (Want to Visit, Visited, Unvisited). When an item's visit status changed:

1. The database update was successful
2. YapDatabase notifications were sent
3. However, the grouped view wasn't properly notifying observers about items moving between groups
4. This is because YapDatabase views with grouping need to be "touched" with a new versionTag to force re-evaluation when grouped data changes

## Solution
Implemented a refresh mechanism similar to how favorites and filtered views handle updates:

1. Added `refreshVisitStatusGroupedViewWithCompletionBlock:` method to force the view to re-evaluate
2. This method sets the view's grouping and sorting with a new UUID versionTag
3. The new versionTag forces YapDatabase to re-evaluate the view and send proper change notifications

## Implementation Details

### Files Modified

#### 1. BRCDatabaseManager.h
Added method declaration:
```objc
/** Refresh visit status grouped view to force re-evaluation */
- (void) refreshVisitStatusGroupedViewWithCompletionBlock:(void (^_Nullable)(void))completionBlock;
```

#### 2. BRCDatabaseManager.m (lines 1018-1047)
Implemented the refresh method that:
- Gets the view transaction for `allObjectsGroupedByVisitStatusViewName`
- Re-creates the same grouping logic used during initial setup
- Sets grouping and sorting with a new UUID versionTag to force re-evaluation

#### 3. VisitListViewController.swift
- Removed the 30-second timer-based refresh (inefficient)
- Added call to `refreshVisitStatusGroupedView` in `viewWillAppear`
- This ensures the view updates when returning from detail screen

#### 4. DetailDataService.swift (lines 66-69)
- Modified `updateVisitStatus` to call refresh after database update
- This ensures immediate updates when visit status changes

## Technical Details

### How YapDatabase View Refresh Works
1. YapDatabase views maintain a versionTag for change tracking
2. When the versionTag changes, the view is forced to re-evaluate all objects
3. This re-evaluation generates proper change notifications for observers
4. The table view adapter receives these notifications and updates the UI

### Why Grouped Views Need Special Handling
- Normal views track individual object changes
- Grouped views need to track when objects move between groups
- Without refresh, YapDatabase may not detect cross-group movements
- The refresh forces complete re-evaluation, ensuring all changes are detected

## Testing Notes
- Build succeeded with all changes
- Visit list now updates immediately when changing visit status in detail view
- No more need for timer-based refresh
- Real-time updates work for all transitions:
  - Unvisited → Want to Visit
  - Unvisited → Visited
  - Want to Visit → Visited
  - Visited → Want to Visit
  - Any status → Unvisited

## Related Work
This follows the same pattern used for:
- Favorites filtering (`refreshFavoritesFilteredView`)
- Event day filtering (`refreshEventFilteredViews`)
- Art events filtering (`refreshArtFilteredView`)

## Future Considerations
- Consider implementing a more generic refresh mechanism for all grouped views
- Could potentially use KVO or notifications to trigger refresh automatically
- May want to batch multiple updates before refreshing for performance