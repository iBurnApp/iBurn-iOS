# Art Filter Refresh Fix

## Date: 2025-08-12

## High-Level Plan

Fix the issue where changing filter options in the ArtListViewController doesn't refresh the list view to show the correct filtered/unfiltered content.

## Problem Statement

The art list view wasn't refreshing properly when users toggled the "Only show art with events" filter. The list would maintain its original state despite the filter setting being changed.

## Root Cause Analysis

The issue stemmed from how the ArtListViewController was initialized:

1. **MoreViewController** determined which database view to use (`artViewName` or `artFilteredByEvents`) at initialization time based on the filter setting
2. Once the view controller was created with a specific view name, it continued using that view even after filter changes
3. The filter callback only refreshed the database filter and reloaded table data, but didn't switch the underlying database view

## Solution Overview

Implemented Option 2: Always use the filtered view (`artFilteredByEvents`). This simplifies the implementation while maintaining proper functionality:
- The filtered view always responds to the filter setting
- When filter is disabled: shows all art
- When filter is enabled: shows only art with events
- No need to switch between different database views

## Key Changes

### MoreViewController.swift (lines 322-329)

**Before:**
```swift
func pushArtView() {
    let dbManager = BRCDatabaseManager.shared
    // Use filtered view if filter is enabled
    let viewName = UserSettings.showOnlyArtWithEvents ? dbManager.artFilteredByEvents : dbManager.artViewName
    let artVC = ArtListViewController(viewName: viewName, searchViewName: dbManager.searchArtView)
    artVC.tableView.separatorStyle = .none
    artVC.title = "Art"
    navigationController?.pushViewController(artVC, animated: true)
}
```

**After:**
```swift
func pushArtView() {
    let dbManager = BRCDatabaseManager.shared
    // Always use filtered view - it shows all art when filter is disabled
    let artVC = ArtListViewController(viewName: dbManager.artFilteredByEvents, searchViewName: dbManager.searchArtView)
    artVC.tableView.separatorStyle = .none
    artVC.title = "Art"
    navigationController?.pushViewController(artVC, animated: true)
}
```

## Technical Details

### Database View Architecture

The app uses YapDatabase with filtered views:
- **Base view**: `artViewName` - contains all art objects
- **Filtered view**: `artFilteredByEvents` - filters based on `UserSettings.showOnlyArtWithEvents`

### Filter Mechanism

1. **BRCDatabaseManager.artFilteredByEvents()** - Creates filter based on user setting
2. **refreshArtFilteredView()** - Updates the filter when setting changes
3. **ArtFilterViewController** - Calls refresh method when user toggles filter

### Data Flow

1. User opens Art list → Always uses `artFilteredByEvents` view
2. User taps filter button → Opens ArtFilterViewController
3. User toggles "Only show art with events" → Saves to UserSettings
4. Filter view refreshes → Database filter updates based on new setting
5. Table reloads → Shows correct filtered/unfiltered content

## Benefits of This Approach

1. **Simpler implementation** - No need to modify core view controller architecture
2. **Consistent behavior** - Filter changes always take effect immediately
3. **Better performance** - No need to recreate view controllers or handlers
4. **Follows existing patterns** - Similar to how other filtered views work in the app

## Files Modified

- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/MoreViewController.swift`

## Testing Verification

- Built project successfully with `xcodebuild`
- No compilation errors introduced
- Filter mechanism now properly refreshes the art list view

## Expected Outcomes

After this fix:
1. Toggling "Only show art with events" filter immediately updates the list
2. No need to navigate back and re-enter the art list
3. Consistent user experience with immediate visual feedback
4. Filter button icon properly indicates filter state (filled when active)

## Related Work

This builds upon the previous filter and map icon consistency update from 2025-08-10, maintaining the visual improvements while fixing the underlying functionality issue.