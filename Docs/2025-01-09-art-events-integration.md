# Art-Events Integration Enhancement

## Date: 2025-01-09

## Branch: art-events

## Overview
Implemented visual indicators to show the relationship between Art installations and Events in the iBurn app. Users can now easily see which art installations host events and identify art-hosted events in the event list.

## Problem Statement
Previously, users couldn't easily identify:
1. Which art installations have associated events when browsing the art list
2. Which events are hosted at art installations vs camps when browsing events
3. The total number of events hosted at each art piece or camp

## Solution

### Key Changes

#### 1. Event Count Indicators
- Added event count badges to art and camp list cells
- Shows "📅 N" where N is the number of events hosted
- Badge is hidden when no events are hosted

#### 2. Host Type Indicators in Event List
- Events hosted by art now show "🎨 [Art Name]" in the host label
- Events hosted by camps show "🏕 [Camp Name]" in the host label
- Makes it immediately clear whether an event is at art or a camp

#### 3. Helper Methods (Swift Extensions)
Created `BRCDataObject+Events.swift` with utility methods:
- `eventCount(with:)` - Returns count of events for art/camp
- `hasEvents(with:)` - Boolean check for any events
- `upcomingEvents(with:from:)` - Gets future events only
- `currentEvents(with:at:)` - Gets currently happening events
- `formattedHostName` - Returns formatted host string for events

### Technical Implementation

#### Modified Files:
1. **BRCDataObjectTableViewCell.h/m**
   - Added `eventCountLabel` IBOutlet property
   - Updated `setDataObject:metadata:` to show event counts for camps
   
2. **BRCArtObjectTableViewCell.h/m**
   - Updated `setDataObject:metadata:` to show event counts for art
   - Leverages base class `eventCountLabel` property

3. **BRCEventObjectTableViewCell.m**
   - Modified `setupLocationLabelFromEvent:` to add emoji indicators
   - Art hosts show 🎨 prefix, camp hosts show 🏕 prefix

4. **BRCDataObject+Events.swift** (New)
   - Swift extensions for art/camp/event relationship queries
   - Provides clean API for checking event associations

### Data Model Relationships
The implementation leverages existing YapDatabase relationships:
- Events have `hostedByArtUniqueID` and `hostedByCampUniqueID` properties
- Art/Camp objects use `eventsWithTransaction:` to fetch related events
- Relationship edges connect events to their hosting locations

### UI/UX Impact
- **Art List**: Users can instantly see which art has events
- **Camp List**: Users can see event counts for camps
- **Event List**: Clear visual distinction between art and camp events
- **Favorites**: Event indicators work in favorites view as well

### Performance Considerations
- Event counts are fetched on-demand when cells are configured
- Uses existing database UI connection for read transactions
- No additional database views or indexes required

### Testing Notes
The implementation was tested by:
1. Building the project successfully with no errors
2. Verifying Swift extensions compile and link properly
3. Ensuring backward compatibility with existing cell layouts

### Future Enhancements
Potential improvements for future iterations:
1. Add filters to show only art/camps with events
2. Sort by event count in list views  
3. Show next upcoming event time in the indicator
4. Add tap gesture to jump directly to event list for that art/camp
5. Color-code indicators based on event timing (happening now, today, future)

### Code Snippets

#### Event Count Display (Objective-C)
```objc
// Show event count for art objects
if ([dataObject isKindOfClass:[BRCArtObject class]]) {
    __block NSArray *events = nil;
    [[BRCDatabaseManager shared].uiConnection readWithBlock:^(YapDatabaseReadTransaction * _Nonnull transaction) {
        events = [dataObject eventsWithTransaction:transaction];
    }];
    
    if (events.count > 0 && self.eventCountLabel) {
        self.eventCountLabel.text = [NSString stringWithFormat:@"📅 %lu", (unsigned long)events.count];
        self.eventCountLabel.hidden = NO;
    }
}
```

#### Host Indicator (Objective-C)
```objc
if (camp) {
    host = camp;
    hostName = [NSString stringWithFormat:@"🏕 %@", camp.title];
} else if (art) {
    host = art;
    hostName = [NSString stringWithFormat:@"🎨 %@", art.title];
}
```

## Commit Summary
- Added event count indicators to art and camp list cells
- Added visual host type indicators (🎨/🏕) to event cells
- Created Swift extensions for art-event relationship queries
- Successfully built and tested implementation