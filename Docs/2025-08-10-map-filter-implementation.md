# Map Filter Implementation

## Date: 2025-08-10

## Overview
Added a comprehensive filter screen for the main map view that allows users to toggle visibility of different data types and favorites.

## Features Implemented

### Filter Options
1. **Art** - Toggle visibility of art installations
2. **Camps** - Toggle visibility of camps
3. **Active Events** - Show only currently happening events
4. **Favorites** - Toggle visibility of all favorited items
5. **Today's Favorites Only** - When favorites are shown, optionally filter to only show today's favorited events

## Technical Implementation

### Files Created
1. **MapFilterView.swift** - SwiftUI view for the filter interface
   - View model with published properties for each filter option
   - Settings persistence through UserSettings
   - Clear visual feedback with footer text explaining current filter state

2. **FilteredMapDataSource.swift** - Dynamic data source that applies filters
   - Inherits from NSObject and conforms to AnnotationDataSource protocol
   - Aggregates multiple data sources (art, camps, events, favorites)
   - Applies filters based on UserSettings preferences
   - Handles "today's favorites only" filtering logic

### Files Modified

1. **UserSettings.swift**
   - Added new properties for map filter preferences:
     - `showArtOnMap` (default: true)
     - `showCampsOnMap` (default: true)
     - `showActiveEventsOnMap` (default: true)
     - `showFavoritesOnMap` (default: true)
     - `showTodaysFavoritesOnlyOnMap` (default: false)

2. **MainMapViewController.swift**
   - Replaced static data sources with FilteredMapDataSource
   - Added filter button to navigation bar
   - Implemented `filterButtonPressed` method to present filter screen
   - Recreates data source and reloads annotations when filters change

## Architecture Decisions

### Data Source Design
- Used composition pattern with FilteredMapDataSource wrapping individual data sources
- Each data type (art, camps, events) has its own YapViewAnnotationDataSource
- Favorites filtering is handled separately to avoid duplication
- User pins are always shown regardless of filter settings

### Filter Logic
- Non-favorited items are filtered out if already shown as favorites
- Today's events filtering uses Calendar.isDate(inSameDayAs:) for accurate day comparison
- Active events use the existing eventsFilteredByDayExpirationAndTypeViewName view

### UI/UX Considerations
- Used SwiftUI for modern, declarative UI
- Filter icon uses SF Symbol "line.horizontal.3.decrease.circle" for consistency
- Disabled "Today's Favorites Only" toggle when favorites are hidden
- Added contextual footer text to explain current filter state

## Integration Points

### Database Views Used
- `BRCDatabaseManager.shared.artViewName` - All art installations
- `BRCDatabaseManager.shared.campsViewName` - All camps
- `BRCDatabaseManager.shared.eventsFilteredByDayExpirationAndTypeViewName` - Active events
- `BRCDatabaseManager.shared.everythingFilteredByFavorite` - All favorites
- `BRCDatabaseManager.shared.everythingFilteredByFavoriteAndExpiration` - Non-expired favorites

### User Collections
- `BRCUserMapPoint.yapCollection` - User-placed pins (always shown)

## Testing Notes
- Build succeeds with all new files integrated
- Filter settings persist across app launches via UserDefaults
- Map annotations reload correctly when filters change
- No impact on existing functionality

## Future Enhancements
- Could add preset filter combinations (e.g., "Show only events", "Show only infrastructure")
- Animation when filter changes are applied
- Badge on filter button showing number of active filters
- Search within filtered results