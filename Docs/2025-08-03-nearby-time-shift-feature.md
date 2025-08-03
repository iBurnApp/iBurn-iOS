# Nearby Time Shift Feature Implementation

**Date:** August 3, 2025  
**Developer:** Claude Code  
**Status:** Complete  

## Overview

Implemented a comprehensive time-shift feature for the Nearby screen that allows users to explore events, art, and camps as if they were at a different time and/or location. This enables users to plan ahead and see what will be available at future times during Burning Man.

## Problem Statement

Users needed the ability to:
1. View upcoming events and activities in the Nearby screen
2. Plan their schedule by seeing what will be happening at different times
3. Optionally change their location to explore different areas of Black Rock City
4. Have their time-shift preferences persist between app sessions

## Solution Overview

Created a time-shift system using modern SwiftUI/UIKit integration patterns with dependency injection and proper architectural separation.

## Technical Implementation

### Architecture Components

#### 1. Core Model
- **TimeShiftConfiguration.swift**: Data structure holding time/location shift state
  - `date: Date` - The shifted time
  - `location: CLLocation?` - Optional location override  
  - `isActive: Bool` - Whether time shifting is currently enabled

#### 2. ViewModel Layer
- **TimeShiftViewModel.swift**: ObservableObject managing state and business logic
  - Dependency injection friendly design
  - Separate callbacks for cancel/apply actions
  - Real-time change detection with `hasUnsavedChanges`
  - Computed properties for time offset display

#### 3. SwiftUI Interface
- **TimeShiftView.swift**: Main sheet interface with medium/large detents
  - Date/time picker wheel interface
  - Quick action buttons (Now, +1 Day, Sunset)
  - Real-time preview of selected time
- **TimeShiftMapView.swift**: Interactive map for location selection
  - MapLibre integration with custom annotations
  - Tap-to-select location functionality
  - Visual feedback with orange pin markers

#### 4. UIKit Integration
- **TimeShiftViewController.swift**: UIHostingController bridge
  - Proper sheet presentation configuration
  - Medium/large detent support with drag indicator
- **NearbyViewController.swift**: Enhanced with time-shift capability
  - Navigation bar button with time offset display
  - Visual indicators when time-shifted (orange styling)
  - Info label showing current shifted time
  - Integration with existing BRCDataSorter filtering

#### 5. Persistence Layer
- **UserSettings.swift**: Extended with time-shift configuration storage
  - Automatic save/restore of time-shift state
  - Proper cleanup when time-shift is disabled
  - Separate keys for date and location components

### UI/UX Design

#### Navigation Bar Integration
- Left navigation bar item shows current time state
- "Now" when not time-shifted
- "+1d", "-3h" etc. format for time shifts
- Orange styling when active to indicate shifted state

#### Sheet Presentation
- Medium detent by default (shows map + basic controls)
- Large detent for full interface access
- Drag indicator for discoverability
- Proper SwiftUI navigation with Cancel/Apply buttons

#### Visual Feedback
- Orange color theming throughout for time-shift indicators
- Info label in table header showing shifted date/time
- Map annotations with distinctive orange pins
- Real-time preview of selected time formatting

### Integration with Existing Systems

#### Event Filtering
- Modified `BRCDataSorter` calls to use shifted date as `options.now`
- Enabled `showExpiredEvents` and `showFutureEvents` when time-shifting
- Preserved existing filter logic (All/Events/Art/Camps)

#### Location Services  
- Override `getCurrentLocation()` to return shifted location when active
- Seamless integration with existing location-based queries
- Fallback to real location when not overridden

#### Data Persistence
- Automatic save/restore through UserSettings
- Survives app restarts and background/foreground cycles
- Clean removal of settings when disabled

## Code Structure

```
iBurn/TimeShift/
├── TimeShiftConfiguration.swift    # Core data model
├── TimeShiftViewModel.swift        # Business logic & state
├── TimeShiftView.swift            # Main SwiftUI interface  
├── TimeShiftMapView.swift         # Map interaction component
└── TimeShiftViewController.swift   # UIKit bridge controller

iBurn/
├── NearbyViewController.swift     # Enhanced with time-shift
└── UserSettings.swift            # Extended with persistence
```

## Key Features Implemented

### Time Control
- Full date/time picker with festival date range limits
- Quick action buttons for common selections
- Real-time offset calculation and display
- Reset to current time functionality

### Location Override
- Interactive map with tap-to-select
- Visual confirmation with custom orange pins
- Toggle to enable/disable location override
- Integration with existing location-based searches

### Persistence
- Automatic save of time-shift configuration
- Restoration on app launch
- Clean settings management

### Visual Indicators
- Navigation bar time offset display
- Orange styling for active time-shift
- Table header info showing shifted date/time
- Proper dark/light mode support

## Testing Results

- ✅ Successfully builds on iOS Simulator (iPhone 16 Pro ARM64)
- ✅ Proper SwiftUI/UIKit integration with no retain cycles
- ✅ Sheet presentation with medium/large detents working
- ✅ Date picker respects YearSettings festival boundaries
- ✅ Map interaction and location selection functional
- ✅ Persistence through UserSettings working correctly
- ✅ Visual styling consistent with app theme

## Files Modified/Created

### New Files Created:
- `iBurn/TimeShift/TimeShiftConfiguration.swift`
- `iBurn/TimeShift/TimeShiftViewModel.swift` 
- `iBurn/TimeShift/TimeShiftView.swift`
- `iBurn/TimeShift/TimeShiftMapView.swift`
- `iBurn/TimeShift/TimeShiftViewController.swift`

### Existing Files Modified:
- `iBurn/NearbyViewController.swift` - Added time-shift integration
- `iBurn/UserSettings.swift` - Added persistence support

## Future Enhancement Opportunities

1. **Quick Presets**: Add buttons for common times like "Tomorrow Morning", "Tonight", "Sunset"
2. **Multiple Screens**: Extend time-shift to Events list and Map views
3. **Favorites Integration**: Time-shifted favorites with scheduling
4. **Social Features**: Share time-shifted views with friends
5. **Advanced Filtering**: Filter by event duration or specific time ranges

## Architectural Benefits

1. **Clean Separation**: UIKit/SwiftUI boundaries well-defined
2. **Testable**: Dependency injection enables unit testing
3. **Reusable**: Components can be used in other contexts
4. **Maintainable**: Clear responsibilities and modern patterns
5. **Extensible**: Easy to add new features or screens

## Performance Considerations

- Efficient use of `@Published` properties for reactive updates
- Proper memory management with weak references
- Minimal impact on main thread with background data sorting
- Smart caching through existing BRCDatabaseManager systems

## Conclusion

The time-shift feature has been successfully implemented with modern iOS development practices, clean architecture, and excellent user experience. The feature integrates seamlessly with existing systems while providing powerful new functionality for Burning Man attendees to plan their festival experience.

The implementation demonstrates effective use of:
- SwiftUI + UIKit hybrid architecture
- Dependency injection and clean separation of concerns  
- Modern sheet presentation APIs
- Reactive programming with Combine
- Proper state management and persistence

The feature is ready for user testing and can be easily extended to other parts of the app as needed.