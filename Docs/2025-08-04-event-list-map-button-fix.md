# Event List Map Button Fix

## Date: 2025-08-04

## High-Level Plan

Fixed the issue where events weren't appearing on the map when using the Map button from the Event List screen.

## Problem Analysis

The initial implementation had a bug where no events were showing on the map despite:
1. Events having location data (copied from camps/art during import)
2. The map button being correctly implemented
3. The annotation data source being properly connected

### Root Cause
The `YapViewAnnotationDataSource` was filtering events using `shouldShowOnMap()`, which only returns true for events that are:
- Starting within 30 minutes OR happening right now
- NOT ending soon
- NOT already ended

This filtering is appropriate for the main map but not for showing events from a list view.

## Solution

Added a `showAllEvents` flag to `YapViewAnnotationDataSource` that bypasses the temporal filtering for events.

## Key Changes

### AnnotationDataSource.swift
1. **Added showAllEvents property** (lines 35, 37-39)
   - `public var showAllEvents: Bool = false`
   - Updated initializer to accept `showAllEvents` parameter

2. **Modified filtering logic** (line 88)
   - Changed from: `if event.shouldShowOnMap()`
   - Changed to: `if showAllEvents || event.shouldShowOnMap()`

### EventListViewController.swift
1. **Updated mapButtonPressed** (line 205)
   - Pass `showAllEvents: true` when creating data source
   - Ensures all events from the list appear on the map

## Technical Details

### Design Decisions
- Maintained backward compatibility by defaulting `showAllEvents` to false
- Other screens using `YapViewAnnotationDataSource` continue to work as before
- The fix is specific to list views that want to show all their items on a map

### Alternative Approaches Considered
- Creating a separate data source class - rejected as too much code duplication
- Removing `shouldShowOnMap()` entirely - rejected as it's needed for the main map

## Build Status

✅ Project builds successfully with no errors

## Expected Behavior

1. Events screen shows map button in navigation bar (left side)
2. Tapping map button shows ALL events from the current list on the map
3. Events appear regardless of their start/end times
4. The map zooms to show all event pins
5. Other map views (main map, nearby) continue to filter events by time as before

## Testing Notes

- All events with valid locations should now appear on the map
- Events without location data (no host camp/art) still won't appear
- Day picker filter on Event List should affect which events show on the map
- The fix doesn't affect how events appear on other map screens