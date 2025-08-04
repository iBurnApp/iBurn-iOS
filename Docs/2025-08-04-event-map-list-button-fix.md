# Event Map List Button Fix

## Date: 2025-08-04

## High-Level Plan

Fixed the issue where the list button on the event map view showed an empty list due to aggressive event filtering.

## Problem Analysis

When pressing the list button on the event map:
1. ListButtonHelper correctly passed annotations to MapPinListViewController
2. MapPinListViewController filtered annotations by visible bounds (working correctly)
3. BRCDataSorter was called to sort the data objects
4. **BRCDataSorter filtered out ALL events** based on timing restrictions

### Root Cause
The default `BRCDataSorterOptions` has:
- `showExpiredEvents = false` - filters out past events
- `showFutureEvents = false` - filters out future events

This means only events happening "right now" would be shown, resulting in an empty list for most cases.

## Solution

Updated MapPinListViewController to show all events regardless of timing by setting both flags to true.

## Key Changes

### MapPinListViewController.swift (lines 61-62)
```swift
let options = BRCDataSorterOptions()
options.showExpiredEvents = true  // Show all events regardless of timing
options.showFutureEvents = true   // Show all events regardless of timing
```

## Technical Details

### Why This Works
- The map shows event pins regardless of timing (controlled by showAllEvents flag)
- The list should show the same events that are visible on the map
- Setting both flags to true ensures timing doesn't filter out events
- Events are still sorted by distance if location is available

### Other Components Unchanged
- ListButtonHelper continues to work as designed
- MapPinListViewController still filters by visible bounds
- BRCDataSorter still sorts by distance when available

## Build Status

✅ Project builds successfully with no errors

## Expected Behavior

1. Open Event List screen
2. Tap map button to see events on map
3. Tap list button on the map view
4. List shows all event pins visible in the current map bounds
5. Events are sorted by distance from current location (if available)

## Related Issues

This fix complements the earlier changes:
- Added map button to Event List screen
- Fixed events not showing on map with showAllEvents flag
- Now the list button properly shows those same events