# Event Type Filter Cleanup

**Date**: 2025-08-16  
**Branch**: mark-visit

## Problem Statement

The events filter view in the iOS app was showing 18 different event types, but analysis of the 2025 event data revealed that only 8 event types actually have events. This created unnecessary clutter in the filter UI with 11 event types that would never match any events.

## Analysis Results

### Event Types in 2025 Data (4,568 total events):
1. **Class/Workshop** (`work`) - 1,429 events (31.28%)
2. **Music/Party** (`prty`) - 1,084 events (23.73%)
3. **Other** (`othr`) - 780 events (17.08%)
4. **Beverages** (`tea`) - 440 events (9.63%)
5. **Food** (`food`) - 314 events (6.87%)
6. **Arts & Crafts** (`arts`) - 300 events (6.57%)
7. **Mature Audiences** (`adlt`) - 180 events (3.94%)
8. **Kids Activities** (`kid`) - 41 events (0.90%)

### Unused Event Types (0 events each):
- Performance (`perf`)
- Support/Self Care (`care`)
- Ceremony (`cere`)
- Game (`game`)
- Fire/Spectacle (`fire`)
- Parade (`para`)
- Live Music (`live`)
- RIDE/Diversity (`RIDE`)
- Repair (`repr`)
- Sustainability (`sust`)
- Meditation/Yoga (`yoga`)

## Solution Implemented

### 1. Updated Event Type Visibility (`BRCEventObject.swift`)

Modified the `isVisible` property to hide unused event types and make the switch exhaustive:

```swift
var isVisible: Bool {
    switch self {
    case .unknown, .none:
        return false
    // These event types are no longer used in the data as of 2025
    case .healing, .LGBT, .performance, .support, .ceremony, .game, 
         .fire, .parade, .liveMusic, .RIDE, .repair, .sustainability, .meditation:
        return false
    // Only show event types that actually have events in 2025:
    case .workshop, .party, .other, .coffee, .food, .crafts, .adult, .kid:
        return true
    @unknown default:
        return false
    }
}
```

### 2. Updated Display Strings to Match 2025 Data

Updated the display strings to match the actual labels from the 2025 API data:

- "Gathering/Party" → "Music/Party"
- "Miscellaneous" → "Other"
- "For Kids" → "Kids Activities"
- "Food & Drink" → "Food"
- "Coffee/Tea" → "Beverages"

## Files Modified

- `/Users/chrisbal/Documents/Code/iBurn-iOS-2/iBurn/BRCEventObject.swift`

## Testing

- ✅ Build succeeded with Xcode
- The event filter now only shows the 8 event types that actually have events in the 2025 data
- Made the enum switch exhaustive for better Swift type safety

## Impact

This change significantly improves the user experience by:
1. Reducing clutter in the event filter UI
2. Preventing confusion from selecting filters that would never return results
3. Accurately reflecting the event categorization used by Burning Man in 2025
4. Maintaining type safety with exhaustive enum switches

## Notes

- The Coffee/Tea type (`tea`) was previously hidden but has been re-enabled since it maps to "Beverages" with 440 events
- The enum remains backwards compatible - old event types are still defined, just hidden from the UI
- This cleanup is based on actual 2025 data analysis showing which event types are being used