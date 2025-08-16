# Fix Event Timezone Display in Detail Screen

**Date:** 2025-08-15  
**Issue:** Events showing in local device timezone instead of fixed Playa timezone (PDT)  
**Solution:** Updated DateFormatter instances to use Burning Man timezone

## Problem Statement

Events were displaying in the user's local device timezone instead of the fixed Playa timezone (PDT) on the detail screen. This caused confusion when users in different timezones viewed event times that didn't match the actual event schedule at Burning Man.

## Root Cause Analysis

The SwiftUI detail view components (`DetailView.swift` and `DetailViewModel.swift`) were using standard `DateFormatter` instances without setting the proper timezone. While the app had proper timezone infrastructure defined (`TimeZone.burningManTimeZone` = PDT), the SwiftUI views weren't utilizing it.

### Affected Components:
- `DetailDateCell.formattedDate` - Used DateFormatter without timezone
- `DetailNextHostEventCell.formatEventTimeAndDuration()` - Used DateFormatter without timezone  
- `DetailViewModel.formatEventSchedule()` - Used DateFormatter without timezone

## Solution Implementation

Updated all DateFormatter instances in the SwiftUI detail views to use the Burning Man timezone (PDT). This ensures events display in Playa time regardless of the user's device timezone settings.

### Files Modified

#### 1. `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/Detail/Views/DetailView.swift`

**DetailDateCell (lines 556-560):**
```swift
// Before
private var formattedDate: String {
    let formatter = DateFormatter()
    formatter.dateFormat = format
    return formatter.string(from: date)
}

// After
private var formattedDate: String {
    let formatter = DateFormatter()
    formatter.dateFormat = format
    formatter.timeZone = TimeZone.burningManTimeZone
    return formatter.string(from: date)
}
```

**DetailNextHostEventCell.formatEventTimeAndDuration() (lines 608-624):**
```swift
// Added timezone to timeFormatter
timeFormatter.timeZone = TimeZone.burningManTimeZone

// Added timezone to dayFormatter
dayFormatter.timeZone = TimeZone.burningManTimeZone
```

#### 2. `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/Detail/ViewModels/DetailViewModel.swift`

**formatEventSchedule() method (lines 484-489):**
```swift
// Before
let dayFormatter = DateFormatter()
dayFormatter.dateFormat = "EEEE M/d"

let timeFormatter = DateFormatter()
timeFormatter.timeStyle = .short

// After
let dayFormatter = DateFormatter()
dayFormatter.dateFormat = "EEEE M/d"
dayFormatter.timeZone = TimeZone.burningManTimeZone

let timeFormatter = DateFormatter()
timeFormatter.timeStyle = .short
timeFormatter.timeZone = TimeZone.burningManTimeZone
```

**generateMetadataCells() method (lines 616-623):**
```swift
// Added timezone to last updated formatter
formatter.timeZone = TimeZone.burningManTimeZone
```

## Technical Details

### Burning Man Timezone Configuration
The app defines the Burning Man timezone in `DateFormatter+iBurn.swift`:
```swift
extension TimeZone {
    /// Gerlach time / PDT
    static let burningManTimeZone = TimeZone(abbreviation: "PDT")!
}
```

This timezone is consistently used throughout the app's Objective-C components but was missing from the newer SwiftUI detail views.

### Testing
- Build succeeded with all changes
- All DateFormatter instances in detail views now properly configured with PDT timezone
- Events will display in Playa time regardless of user's device timezone

## Impact
- Events now display consistently in PDT (Playa time)
- Users in any timezone see the correct event times as they occur at Burning Man
- Aligns SwiftUI detail views with existing Objective-C event cell behavior

## Future Considerations
- Consider creating reusable DateFormatter extensions for event-specific formatting
- Add unit tests to verify timezone handling in detail views
- Document timezone handling conventions for future SwiftUI migrations