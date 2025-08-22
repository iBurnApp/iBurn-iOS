# Fix Detail Screen Distance Display and Event Times

## Date: 2025-08-22

## Problem Statement
The SwiftUI detail screen had two issues:
1. Distance was displayed in meters instead of feet
2. "All Day" events only showed "All Day" without actual start/end times

## Solution Overview
Fixed both issues and added walk/bike time estimates as a separate cell for better user experience.

## Key Changes

### 1. Distance Display Fix
**File**: `iBurn/Detail/Views/DetailView.swift`
- Modified `DetailDistanceCell` to convert meters to feet (1 meter = 3.28084 feet)
- Changed display format from "Distance: X meters" to "Distance: X ft"

### 2. Added Walk/Bike Time Estimates
**Files Modified**:
- `iBurn/Detail/Models/DetailCellType.swift`: Added new `.travelTime(CLLocationDistance)` case
- `iBurn/Detail/Views/DetailView.swift`: 
  - Created new `DetailTravelTimeCell` view
  - Added case handling in `DetailCellView`
  - Updated `isCellTappable` function
- `iBurn/Detail/ViewModels/DetailViewModel.swift`: Added travel time cell after distance cell

The new cell uses the existing `TTTLocationFormatter.brc_humanizedString(forDistance:)` to display:
- Walking time with emoji 🚶🏽
- Biking time with emoji 🚴🏽
- Color coding (green/orange/red) based on difficulty

### 3. All Day Event Times Fix
**File**: `iBurn/Detail/ViewModels/DetailViewModel.swift`
- Modified `formatEventSchedule` method
- Changed "All Day" events to display: "All Day (startTime - endTime)"
- Provides clarity on actual event hours while maintaining "All Day" designation

## Technical Details

### Code Snippets

#### Distance Cell Update
```swift
struct DetailDistanceCell: View {
    let distance: CLLocationDistance
    @Environment(\.themeColors) var themeColors
    
    var body: some View {
        HStack {
            Image(systemName: "ruler")
                .foregroundColor(themeColors.detailColor)
            Text("Distance: \(distance * 3.28084, specifier: "%.0f") ft")
                .foregroundColor(themeColors.detailColor)
            Spacer()
        }
    }
}
```

#### New Travel Time Cell
```swift
struct DetailTravelTimeCell: View {
    let distance: CLLocationDistance
    @Environment(\.themeColors) var themeColors
    
    var body: some View {
        if let attributedString = TTTLocationFormatter.brc_humanizedString(forDistance: distance) {
            HStack {
                Text(AttributedString(attributedString))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
            }
        }
    }
}
```

#### All Day Event Fix
```swift
if event.isAllDay {
    let start = timeFormatter.string(from: startDate)
    let end = timeFormatter.string(from: endDate)
    timeString = "All Day (\(start) - \(end))"
} else {
    let start = timeFormatter.string(from: startDate)
    let end = timeFormatter.string(from: endDate)
    timeString = "\(start) - \(end)"
}
```

## Testing
- Build succeeded with only expected warnings
- Changes are isolated to SwiftUI detail view
- No impact on legacy Objective-C detail view
- Maintains consistency with existing app patterns

## Expected Outcomes
- Users will see distance in feet (more familiar unit for Burning Man context)
- Walk/bike time estimates help with planning navigation at the event
- "All Day" events now show specific hours for better planning

## Notes
- The conversion factor 3.28084 is the standard meters to feet conversion
- TTTLocationFormatter already provides walking/biking time calculations with color coding
- These changes only affect the new SwiftUI detail screen, not the legacy implementation