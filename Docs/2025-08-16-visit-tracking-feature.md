# Visit Tracking Feature Implementation

## Date: 2025-08-16

## Overview
Implemented a comprehensive visit tracking system for iBurn that allows users to mark data objects (art, camps, events) with three states: unvisited, visited, and wantToVisit. This feature integrates with the SwiftUI detail screen, map filtering, and database persistence.

## High-Level Plan

### Problem Statement
Users need a way to track which locations they have visited, want to visit, or haven't visited yet during Burning Man. This helps with planning and remembering experiences.

### Solution Overview
- Added visit status enum with three states: unvisited, visited, wantToVisit
- Extended metadata to store visit status persistently
- Created database views for filtering by visit status
- Added UI controls in detail view for changing status
- Integrated with map filtering system
- Added UserSettings for persistence of filter preferences

## Technical Implementation

### 1. Core Data Model Changes

#### Created BRCVisitStatus Enum
**File**: `iBurn/BRCVisitStatus.swift`
- Enum with cases: `.unvisited`, `.visited`, `.wantToVisit`
- Includes display strings, icons, and colors for UI
- Objective-C compatible for database integration

#### Extended Metadata Classes
**File**: `iBurn/BRCObjectMetadata.h`
- Added `visitStatus` property (NSInteger) to BRCObjectMetadata
- Automatically inherits to subclasses (Art, Camp, Event metadata)

### 2. Database Layer

#### Database Views
**File**: `iBurn/BRCDatabaseManager.m`
- Added new filter types: `BRCDatabaseFilteredViewTypeVisitedOnly`, `BRCDatabaseFilteredViewTypeWantToVisitOnly`, `BRCDatabaseFilteredViewTypeUnvisitedOnly`
- Implemented filtering methods: `visitedOnlyFiltering`, `wantToVisitOnlyFiltering`, `unvisitedOnlyFiltering`
- Registered views: `visitedObjectsViewName`, `wantToVisitObjectsViewName`, `unvisitedObjectsViewName`

### 3. Detail Screen UI

#### Visit Status Cell
**Files**: 
- `iBurn/Detail/Models/DetailCellType.swift` - Added `.visitStatus(BRCVisitStatus)` case
- `iBurn/Detail/Views/DetailView.swift` - Added `DetailVisitStatusCell` SwiftUI view with Menu component
- `iBurn/Detail/ViewModels/DetailViewModel.swift` - Added `updateVisitStatus()` method and cell generation

#### Data Service Updates
**Files**:
- `iBurn/Detail/Protocols/DetailDataServiceProtocol.swift` - Added `updateVisitStatus()` method
- `iBurn/Detail/Services/DetailDataService.swift` - Implemented visit status persistence using `metadataCopy()`

### 4. Map Filtering Integration

#### MapFilterView Updates
**File**: `iBurn/MapFilterView.swift`
- Added toggles for "Show Visited", "Show Want to Visit", "Show Unvisited"
- Added properties to MapFilterViewModel
- Integrated with UserSettings for persistence

### 5. UserSettings Storage

**File**: `iBurn/UserSettings.swift`
Added properties:
- `showVisitedOnMap`: Bool (default true)
- `showWantToVisitOnMap`: Bool (default true)  
- `showUnvisitedOnMap`: Bool (default true)
- `visitStatusFilterForLists`: Set<BRCVisitStatus> (default all statuses)

## UI/UX Design

### Visit Status Cell in Detail View
- Shows current status with icon and color
- Tappable to open SwiftUI Menu
- Menu shows all three options with icons
- Immediate visual feedback on selection

### Visual Indicators
- **Unvisited**: Gray circle icon (○)
- **Visited**: Green checkmark circle (✓)
- **Want to Visit**: Yellow star (★)

### Map Filter Section
- New "Visit Status" section in map filter
- Three independent toggles for maximum flexibility
- Defaults to showing all statuses

## Files Modified

1. **New Files Created**:
   - `iBurn/BRCVisitStatus.swift`
   - `Docs/2025-08-16-visit-tracking-feature.md`

2. **Modified Files**:
   - `iBurn/BRCObjectMetadata.h` - Added visitStatus property
   - `iBurn/BRCDatabaseManager.h/.m` - Added database views and filtering
   - `iBurn/Detail/Models/DetailCellType.swift` - Added visit status case
   - `iBurn/Detail/Views/DetailView.swift` - Added visit status cell UI
   - `iBurn/Detail/ViewModels/DetailViewModel.swift` - Added visit status handling
   - `iBurn/Detail/Protocols/DetailDataServiceProtocol.swift` - Added protocol method
   - `iBurn/Detail/Services/DetailDataService.swift` - Implemented persistence
   - `iBurn/MapFilterView.swift` - Added visit status toggles
   - `iBurn/UserSettings.swift` - Added persistence properties

## Remaining Work

The following components are ready to be implemented but not yet completed:

### FilteredMapDataSource Integration
Need to update `FilteredMapDataSource.swift` to:
- Add data sources for visited/wantToVisit/unvisited views
- Filter annotations based on UserSettings
- Combine with existing favorites filtering

### FavoritesFilterView Integration  
Need to update `FavoritesFilterView.swift` to:
- Add visit status filter options
- Combine with existing expired events filtering

### List View Filtering
Need to add filtering to list views (Events, Camps, Art) to:
- Add filter UI with toggles
- Use filtered database views
- Update table adapters

## Testing Considerations

1. **Data Persistence**: Verify visit status persists across app launches
2. **Filter Combinations**: Test various combinations of filters
3. **UI Updates**: Ensure immediate feedback when status changes
4. **Performance**: Test with large datasets
5. **Default Values**: Verify unvisited is default for new objects

## Future Enhancements

1. **Visual Map Indicators**: Different pin colors/badges based on visit status
2. **Statistics View**: Show visit progress (X visited out of Y total)
3. **Bulk Operations**: Mark multiple items as visited at once
4. **Export Feature**: Export list of visited places
5. **Share Feature**: Share visit list with friends

## Notes

- Used `metadataCopy()` helper instead of force-casting for safer metadata copying
- All three visit statuses are shown by default to avoid confusing users
- Visit status is stored as NSInteger in metadata for Objective-C compatibility
- SwiftUI Menu provides native iOS experience for status selection