# Art-Events Integration & Favorites Filtering PR

## Date: 2025-08-09
## PR: https://github.com/iBurnApp/iBurn-iOS/pull/202
## Branch: art-events

## Overview
Created a comprehensive pull request that combines the art-events integration work with the favorites filtering enhancements.

## Features Included

### 1. Art-Events Visual Indicators
- Event count badges (📅 N) on art and camp list cells
- Host type indicators (🎨/🏕) on event list cells  
- Swift extensions for querying art-event relationships
- Makes it easy to identify which art/camps have events

### 2. Favorites Filtering System
- Filter button in favorites navigation bar
- SwiftUI modal for filter settings
- Options to hide expired events
- Option to show only today's events
- Settings persist in UserDefaults

### 3. Favorites Map Fixes
- Map now respects filter preferences
- Shows all favorited items matching current filters
- Map button properly coexists with filter button
- Fixed override issues with mapButtonPressed

### 4. Test Date Update
- Updated NSDate+iBurn test date from 2023 to 2025
- Ensures tests use current year

## Technical Implementation

### Modified Files
- `BRCDataObjectTableViewCell.h/m` - Added event count label
- `BRCArtObjectTableViewCell.h/m` - Display event counts for art
- `BRCEventObjectTableViewCell.m` - Added host type indicators
- `BRCDatabaseManager.m/h` - Database filtering implementation
- `FavoritesViewController.swift` - Filter UI integration
- `UserSettings.swift` - Filter preference properties
- `ObjectListViewController.swift` - Made mapButtonPressed overridable
- `BRCAppDelegate.m` - Initialize filtered view on startup
- `NSDate+iBurn.m` - Updated test date year

### New Files
- `BRCDataObject+Events.swift` - Event relationship utilities
- `FavoritesFilterView.swift` - SwiftUI filter settings modal

## Testing Checklist
All items should be verified before merging:
- [ ] Build succeeds without errors
- [ ] Art list shows event count badges
- [ ] Camp list shows event count badges  
- [ ] Event list shows host type emoji indicators
- [ ] Favorites filter button appears and works
- [ ] Filter settings persist across app launches
- [ ] Map respects filter preferences
- [ ] All unit tests pass
- [ ] No visual regressions

## PR Status
- Created: 2025-08-09
- URL: https://github.com/iBurnApp/iBurn-iOS/pull/202
- Branch: art-events -> master
- CI Status: Pending

## Commits Included
1. `15c5cb5` - Update test date year from 2023 to 2025
2. `2f5f572` - Add visual indicators for art-event relationships
3. `cc58d46` - Fix today-only filter to respect expired events setting
4. `2508ee4` - Fix favorites map to respect filter preferences
5. `804ee42` - Enhance favorites filtering with today-only and map display options
6. `b26d266` - Fix missing map button in favorites screen
7. `6521938` - Add expired events filter to favorites list

## Notes
- The PR combines multiple related features that work together to improve event discovery
- All changes maintain backward compatibility
- Filter defaults preserve existing behavior (show all favorites)
- Visual indicators are unobtrusive but helpful for navigation