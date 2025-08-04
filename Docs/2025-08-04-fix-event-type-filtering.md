# Fix Event Type Filtering

Date: 2025-08-04

## Problem
The event type filtering mechanism was broken. When users selected specific event types in the filter UI, all events were still being shown instead of just the selected types.

## Root Cause
There was a UserDefaults key mismatch between Swift and Objective-C code:
- Swift UI (EventsFilterView.swift) was saving selected event types using key: `"selectedEventTypes"`
- Objective-C database filter (NSUserDefaults+iBurn.m) was reading using key: `"kBRCSelectedEventsTypesKey"`

Since these are different strings, the UI saved to one location but the database filter read from another, always getting an empty array. The database filter logic treats an empty array as "show all events", which is why all events were displayed regardless of selection.

## Solution
We consolidated the event filtering preferences into the existing UserSettings system:

1. **Added keys to UserSettings.swift**:
   - `selectedEventTypes = "kBRCSelectedEventsTypesKey"`
   - `showExpiredEvents = "kBRCShowExpiredEventsKey"`
   - `showAllDayEvents = "kBRCShowAllDayEventsKey"`

2. **Added properties to UserSettings.swift**:
   - `selectedEventTypes: [BRCEventType]` - handles conversion between Swift enum and NSNumber array
   - `showExpiredEvents: Bool` - marked with @objc for Objective-C compatibility
   - `showAllDayEvents: Bool` - marked with @objc for Objective-C compatibility

3. **Updated EventsFilterView.swift**:
   - Removed the custom UserDefaults extension
   - Changed all references to use UserSettings properties instead
   - This ensures both Swift and Objective-C use the same UserDefaults keys

## Files Modified
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/UserSettings.swift` - Added event filtering properties
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/EventsFilterView.swift` - Updated to use UserSettings

## Testing
The project builds successfully. The filtering should now work correctly because both Swift and Objective-C code are reading/writing to the same UserDefaults keys.

## Technical Details

### Key Constants (from NSUserDefaults+iBurn.m)
```objc
static NSString *const kBRCSelectedEventsTypesKey = @"kBRCSelectedEventsTypesKey";
static NSString *const kBRCShowExpiredEventsKey = @"kBRCShowExpiredEventsKey";
static NSString *const kBRCShowAllDayEventsKey = @"kBRCShowAllDayEventsKey";
```

### Database Filter Logic (BRCDatabaseManager.m)
The filter reads selected event types and creates an NSSet:
```objc
NSSet *filteredSet = [NSSet setWithArray:[[NSUserDefaults standardUserDefaults] selectedEventTypes]];
```

If the set is empty (`[eventTypes count] == 0`), all events pass the filter. This is the intended behavior - no selection means show all events.