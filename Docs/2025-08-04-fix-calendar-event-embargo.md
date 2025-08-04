# Fix Calendar Event Location Embargo

## Date: 2025-08-04

## Problem Statement
When adding events to the calendar from the new detail screen, location information (playa addresses like "3:00 & 500'") was being included even when the data was under embargo. This violated the Burning Man organization's requirement to restrict location data until gates open.

## Solution Overview
Modified the `EventEditControllerFactory` in `EventEditService.swift` to check embargo status before including location information in calendar events. Camp landmarks remain visible as they are not restricted under embargo.

## Technical Implementation

### Modified File
`/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/Detail/Services/EventEditService.swift`

### Key Changes
1. Updated `formatLocationString()` method to check embargo status using `BRCEmbargo.canShowLocation(for:)`
2. When location is embargoed, only the host name is shown (no playa address)
3. Used proper optional handling with `map` instead of force unwrapping

### Code Changes
```swift
// Before
private static func formatLocationString(event: BRCEventObject, host: BRCDataObject?) -> String {
    // Always included playa location regardless of embargo status
}

// After
private static func formatLocationString(event: BRCEventObject, host: BRCDataObject?) -> String {
    // Check embargo status first
    let canShowLocation = host.map { BRCEmbargo.canShowLocation(for: $0) } ?? true
    
    if canShowLocation {
        // Include full playa location
    } else {
        // Only show host name, no coordinates
    }
}
```

## Expected Behavior

### Under Embargo (before gates open, no passcode):
- **Location field**: "Camp Name" (no playa address)
- **Notes field**: Full event description, host description, camp landmarks (unchanged)

### After Embargo Lifted (gates open or passcode entered):
- **Location field**: "3:00 & 500' - Camp Name" (full playa address included)
- **Notes field**: Full event description, host description, camp landmarks (unchanged)

## Testing Notes
- Build succeeded with no compilation errors
- The embargo check follows the same pattern used throughout the codebase
- Camp landmarks remain visible in the notes section as they are not restricted

## Related Files
- `BRCEmbargo.h/m` - Core embargo checking logic
- `DetailActionCoordinator.swift` - Calls the event edit controller factory
- Various UI components that also respect embargo status for consistency