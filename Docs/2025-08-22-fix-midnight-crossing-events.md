# Fix for Midnight-Crossing Events Displaying as "All Day"

## Problem
Users reported that events crossing midnight were incorrectly displayed as "all day" events in iBurn. For example:
- "Hot Dogs & Hard Techno Beats" scheduled for Thursday 10PM-2AM was showing as "all day"
- "The Afro house - Hot Dog Groove" scheduled for Thursday 2PM-6PM was also showing as "all day"

## Root Cause Analysis
The 2025 Burning Man event data contains 255 events with negative durations (end time before start time):
- 75 events: Same date with end before start (true midnight crossers)
- 180 events: Different dates with end before start (data entry errors)

The previous fix in `BRCRecurringEventObject.m` was swapping start and end dates when end < start, which:
1. Didn't correctly handle midnight crossers
2. Created long duration events that were then marked as "all day" (>12 hours)

## Solution Implemented
**Core principle: Trust the start date/time as correct, and apply the end time to the start date.**

### Code Changes in `BRCRecurringEventObject.m`
Replaced the date swap logic with smart date correction:

```objc
// Check if end is before start (negative duration)  
if ([endDate timeIntervalSinceDate:startDate] < 0) {
    NSCalendar *calendar = [NSCalendar currentCalendar];
    
    // Extract time components from end date
    NSDateComponents *endTimeComponents = [calendar components:(NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond) fromDate:endDate];
    
    // Apply end time to start date
    NSDateComponents *startDateComponents = [calendar components:(NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay) fromDate:startDate];
    startDateComponents.hour = endTimeComponents.hour;
    startDateComponents.minute = endTimeComponents.minute;
    startDateComponents.second = endTimeComponents.second;
    
    NSDate *correctedEndDate = [calendar dateFromComponents:startDateComponents];
    
    // If end time is still before start time (same day), it must cross midnight
    if ([correctedEndDate timeIntervalSinceDate:startDate] <= 0) {
        correctedEndDate = [calendar dateByAddingUnit:NSCalendarUnitDay value:1 toDate:correctedEndDate options:0];
    }
    
    endDate = correctedEndDate;
}
```

## Results
This fix successfully handles all 255 problematic events:

### Midnight Crossers (75 events)
Events like "Hot Dogs & Hard Techno Beats":
- Before: Thu 10PM to Thu 2AM (negative duration, marked as "all day")
- After: Thu 10PM to Fri 2AM (4-hour event)

### Data Entry Errors (180 events)  
Events where organizers selected wrong end date:
- "Disco Never Dies": Thu 9AM to Sun 2PM → Thu 9AM to Thu 2PM (5-hour event)
- "Last dance party!": Mon 5:30PM to Sun 5:45PM → Mon 5:30PM to Mon 5:45PM (15-minute event)

## Testing
- Build succeeds with no errors
- All 255 events now have valid positive durations
- Events display correct time ranges instead of "all day"

## Related Issues
- Previous fix documented in: `Docs/2025-08-09-negative-duration-events.md`
- The "all day" threshold remains at 12 hours as originally designed