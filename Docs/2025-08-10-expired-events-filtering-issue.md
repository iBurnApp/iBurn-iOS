# Expired Events Filtering Issue

## Problem Statement
Expired events are not being filtered out properly from the event list screen, even when the "Show Expired Events" setting is disabled. Events that are "ending soon" (within 15 minutes of ending) are incorrectly being treated as expired and filtered out.

## Root Cause Analysis

### The Issue
In `BRCDatabaseManager.m` line 840, the event filtering logic incorrectly combines two conditions:

```objc
BOOL eventHasEnded = [eventObject hasEnded:now] || [eventObject isEndingSoon:now];
```

This causes events that are still happening but will end within 15 minutes to be filtered out as if they were already expired.

### Code Investigation

#### 1. Event List View (BRCDatabaseManager.m:821-853)
The `eventsFilteredByExpiration:eventTypes:artHostedOnly:` method creates a YapDatabase view filter for the Events tab. The problematic line 840 treats "ending soon" events as expired:

```objc
// Line 840 - INCORRECT
BOOL eventHasEnded = [eventObject hasEnded:now] || [eventObject isEndingSoon:now];
```

#### 2. Event Status Methods (BRCEventObject.m)
- `hasEnded:` - Returns YES if event end time is in the past
- `isEndingSoon:` - Returns YES if event ends within 15 minutes (but still ongoing)
- `hasStarted:` - Returns YES if event start time is in the past

#### 3. Other Filtering Implementations (Correct)

**Favorites View (BRCDatabaseManager.m:694,704)**
```objc
// CORRECT - Only uses hasEnded
if (!showExpiredEvents && [eventObject hasEnded:now]) {
    return NO;
}
```

**Nearby View (BRCDataSorter.swift:65)**
```swift
// CORRECT - Only uses hasEnded
if !opt.showExpiredEvents {
    events = events.filter { !$0.hasEnded(opt.now) }
}
```

## Impact
- Events that are still happening but ending within 15 minutes are hidden from the Events list
- This affects users trying to find events that are about to end but still joinable
- Inconsistent behavior between Events tab vs Favorites/Nearby screens

## Solution

### Fix the Filter Logic
Change line 840 in `BRCDatabaseManager.m` from:
```objc
BOOL eventHasEnded = [eventObject hasEnded:now] || [eventObject isEndingSoon:now];
```

To:
```objc
BOOL eventHasEnded = [eventObject hasEnded:now];
```

This aligns the Events tab filtering with the correct implementation used in Favorites and Nearby views.

### Files to Modify
1. `/Users/chrisbal/Documents/Code/iBurn-iOS-2/iBurn/BRCDatabaseManager.m` - Line 840

## Testing Plan
1. Set "Show Expired Events" to OFF in settings
2. Find an event that ends in 10 minutes
3. Verify it appears in the Events list (currently it incorrectly disappears)
4. Wait until the event actually ends
5. Verify it disappears from the Events list when truly expired
6. Compare behavior across Events, Favorites, and Nearby screens for consistency

## Additional Notes
- The `isEndingSoon` status should still be used for visual indicators (orange color/pin) but not for filtering
- This bug only affects the Events tab; Favorites and Nearby screens already filter correctly