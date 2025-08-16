# Visit List UI Fixes and Map Filter Updates
Date: 2025-08-16

## Problem Statement
Multiple UI issues with visit status features:
1. Visit List: Table header with segmented control was getting clipped
2. Visit List: Scrollbar sidebar text was too long ("Want to Visit", "Visited", "Unvisited")
3. Map/Favorites: Visit status filtering not working properly

## Solution Overview
- Fixed table header clipping by adding proper autolayout constraints
- Added emoji-based groupTransformer for compact sidebar display
- Changed default filter to "All" showing only relevant groups
- Removed "Unvisited" from the "All" filter since it would show everything

## Technical Details

### Files Modified
- `/Users/chrisbal/Documents/Code/iBurn-iOS-2/iBurn/VisitListViewController.swift`

### Key Changes

#### 1. Table Header Fix (`setupFilterControl()`)
- Added explicit height constraint to container view (60pt)
- Added proper layout calls to ensure sizing
- Removed fixed frame assignment in favor of autolayout

#### 2. Sidebar Emoji Display (`configureGroupTransformer()`)
- Added new method to configure group transformer
- Maps group names to emojis:
  - "Want to Visit" → "⭐"
  - "Visited" → "✓"

#### 3. Filter Logic Updates
- Changed default filter from `.wantToVisit` to `.all` (index 2)
- Modified `.all` case to only show Want to Visit and Visited groups
- Removed Unvisited group from display (would show everything)

### Code Snippets

#### Group Transformer Implementation
```swift
func configureGroupTransformer() {
    // Use emoji for the sidebar index
    listCoordinator.tableViewAdapter.groupTransformer = { group in
        switch group {
        case BRCVisitStatusGroupWantToVisit:
            return "⭐"
        case BRCVisitStatusGroupVisited:
            return "✓"
        default:
            return group
        }
    }
}
```

#### Updated Filter Logic
```swift
case .all:
    // Only show Want to Visit and Visited, not Unvisited
    groupFilter = .names([BRCVisitStatusGroupWantToVisit, 
                          BRCVisitStatusGroupVisited])
```

### Visit Status Filter Hiding
Temporarily commented out visit status sections in:
- `MapFilterView.swift` (lines 129-137)
- `FavoritesFilterView.swift` (lines 85-108)

Added TODO comments explaining the feature needs proper implementation before re-enabling.
All underlying infrastructure preserved for future use.

## Expected Outcomes
- Table header displays properly without clipping
- Sidebar shows compact emoji indicators for quick navigation
- Default view shows both Want to Visit and Visited items
- Visit status filters hidden from Map and Favorites until properly implemented
- Cleaner, more intuitive interface for tracking festival visits

## Build Verification
Successfully built with xcodebuild for iPhone 16 Pro simulator.