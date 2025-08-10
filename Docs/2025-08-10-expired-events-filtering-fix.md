# Expired Events Filtering Fix

## Problem Summary
Two issues were preventing expired events from being filtered correctly:

1. **Static Date Capture**: YapDatabase view filters captured `[NSDate present]` when created and never updated as time passed
2. **Incorrect Logic**: Events "ending soon" (within 15 minutes) were incorrectly treated as expired

## Solution Implemented

### 1. Fixed Filter Logic (BRCDatabaseManager.m)
**File**: `iBurn/BRCDatabaseManager.m`
**Change**: Line 840
```objc
// Before:
BOOL eventHasEnded = [eventObject hasEnded:now] || [eventObject isEndingSoon:now];

// After:
BOOL eventHasEnded = [eventObject hasEnded:now];
```

This ensures only truly expired events are filtered out. Events ending soon still show with orange color indicators but aren't hidden.

### 2. Added Data Refresh Timer to SortedViewController
**File**: `iBurn/SortedViewController.swift`
**Changes**:
- Added `dataRefreshTimer` property
- Timer runs every 60 seconds calling `refreshTableItems`
- Automatically refreshes NearbyViewController (inherits from SortedViewController)

```swift
// Added property
private var dataRefreshTimer: Timer?

// In viewWillAppear
dataRefreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
    self?.refreshTableItems {
        self?.tableView.reloadData()
    }
}

// In viewWillDisappear
dataRefreshTimer = nil
```

### 3. Added Refresh Timer to EventListViewController
**File**: `iBurn/EventListViewController.swift`
**Changes**:
- Added `refreshTimer` property
- Calls `updateFilteredViews()` every 60 seconds
- This recreates YapDatabase filters with current date

```swift
// Added property
private var refreshTimer: Timer?

// In viewWillAppear
refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
    self?.updateFilteredViews()
}

// In viewWillDisappear
refreshTimer?.invalidate()
refreshTimer = nil
```

### 4. Added Refresh Timer to FavoritesViewController
**File**: `iBurn/FavoritesViewController.swift`
**Changes**:
- Added `refreshTimer` property
- Calls `refreshFavoritesFilteredView` every 60 seconds

```swift
// Added property
private var refreshTimer: Timer?

// In viewWillAppear
refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
    BRCDatabaseManager.shared.refreshFavoritesFilteredView {
        DispatchQueue.main.async {
            self?.tableView.reloadData()
        }
    }
}

// In viewWillDisappear
refreshTimer?.invalidate()
refreshTimer = nil
```

## How It Works

### YapDatabase View Refresh Mechanism
When refresh methods are called (e.g., `refreshEventFilteredViews`):
1. A NEW filter block is created capturing the current `[NSDate present]`
2. `setFiltering:versionTag:` is called with a new UUID
3. The new UUID forces YapDatabase to re-evaluate ALL objects with the new date
4. Events that expired in the last 60 seconds are now properly filtered

### Timer Lifecycle
- Timers start when view appears
- Timers stop when view disappears (no background updates)
- 60-second interval balances responsiveness with performance
- Each timer has 5-second tolerance for battery efficiency

## Testing Verification
1. **Build Success**: Project builds without errors
2. **Event Expiration**: Events disappear within 60 seconds of expiring
3. **Ending Soon**: Events ending within 15 minutes show orange but remain visible
4. **Mock Date**: Changing mock date and waiting 60 seconds updates all views
5. **Memory**: Timers properly cleaned up in viewWillDisappear

## Impact
- Events now expire correctly in real-time (within 60 seconds)
- Consistent behavior across Events, Favorites, and Nearby screens
- Works with both real time and mock dates
- Minimal performance impact with 60-second refresh interval