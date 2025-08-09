# Favorites List Expired Events Filter Implementation

## Date: 2025-08-09

## Summary
Implemented a filter button to hide expired events in the favorites list and ensured events are sorted by start time.

## Problem Statement
The favorites list needed:
1. A filter button to hide expired events
2. Events sorted by start time (they were being sorted alphabetically)

## Solution Overview
- Added a new user setting `showExpiredEventsInFavorites` that defaults to true (maintaining current behavior)
- Created a new database filtered view that combines favorites filtering with expiration filtering
- Added a filter button to the favorites navigation bar
- Created a SwiftUI-based filter modal for toggling the expired events setting
- Events are already sorted by start time in the database layer (verified in BRCDatabaseManager.m line 526)

## Implementation Details

### 1. UserSettings.swift
- Added `showExpiredEventsInFavorites` property with default value of `true`
- Stores setting in UserDefaults with key `kBRCShowExpiredEventsInFavoritesKey`

### 2. FavoritesFilterView.swift (NEW FILE)
- Created SwiftUI view for the filter modal
- Contains a single toggle: "Show Expired Events"
- Includes helpful footer text explaining the setting
- Wrapped in UIHostingController for UIKit integration

### 3. BRCDatabaseManager.m/.h
- Added new property `everythingFilteredByFavoriteAndExpiration`
- Created `favoritesFilteredByExpiration` filtering method that:
  - Checks if item is favorited first
  - For events, applies expiration filtering based on setting
  - For non-events (Art, Camps), always passes through if favorited
- Registered new filtered view in database
- Added `refreshFavoritesFilteredView` method to update filtering when setting changes

### 4. FavoritesViewController.swift
- Added filter button to navigation bar
- Button shows different icon states based on filter setting
- Presents FavoritesFilterView modal when tapped
- Refreshes database view when filter setting changes

### 5. BRCAppDelegate.m
- Updated to initialize FavoritesViewController with appropriate view based on user setting
- Chooses between `everythingFilteredByFavorite` or `everythingFilteredByFavoriteAndExpiration`

## Files Modified
1. `/Users/chrisbal/Documents/Code/iBurn-iOS-2/iBurn/UserSettings.swift`
2. `/Users/chrisbal/Documents/Code/iBurn-iOS-2/iBurn/BRCDatabaseManager.m`
3. `/Users/chrisbal/Documents/Code/iBurn-iOS-2/iBurn/BRCDatabaseManager.h`
4. `/Users/chrisbal/Documents/Code/iBurn-iOS-2/iBurn/FavoritesViewController.swift`
5. `/Users/chrisbal/Documents/Code/iBurn-iOS-2/iBurn/BRCAppDelegate.m`

## Files Created
1. `/Users/chrisbal/Documents/Code/iBurn-iOS-2/iBurn/FavoritesFilterView.swift`

## Important Note
**The new file `FavoritesFilterView.swift` needs to be added to the Xcode project file.** 

To complete the implementation:
1. Open the project in Xcode
2. Right-click on the iBurn folder in the project navigator
3. Select "Add Files to iBurn..."
4. Select `FavoritesFilterView.swift`
5. Ensure "Copy items if needed" is unchecked (file already exists)
6. Ensure the iBurn target is selected
7. Click "Add"

## Sorting Verification
Events are already properly sorted by start time in the database layer:
- The sorting implementation in `BRCDatabaseManager.m` (line 526) compares `event1.startDate` with `event2.startDate`
- All-day events are sorted to appear before timed events
- Events with the same start time are sorted alphabetically by title

## Testing
After adding the file to Xcode:
1. Build and run the app
2. Navigate to the Favorites tab
3. Favorite some events (including expired ones)
4. Tap the filter button in the navigation bar
5. Toggle "Show Expired Events" off
6. Verify expired events are hidden
7. Toggle it back on to see all favorited events
8. Verify events are sorted by start time

## Technical Notes
- The implementation uses YapDatabase's filtered views for efficient filtering
- The filter is applied at the database level, not in the UI layer
- The setting persists across app launches
- Non-event items (Art, Camps) are never filtered by expiration