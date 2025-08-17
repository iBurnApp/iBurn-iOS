# Remove Camp and Event Embargo for 2025

## Date: 2025-08-16

## Problem Statement
For the 2025 Burning Man event, we need to remove the location embargo for camps and events while keeping the art embargo in place. This allows camp and event locations to be displayed before the gates open, while art locations remain restricted.

## Solution Overview
Modified the embargo logic in `BRCEmbargo.m` to comment out the camp and event embargo checks while preserving the art embargo. The code is commented rather than deleted to make it easy to re-enable for 2026.

## Key Changes

### 1. Fixed Import Issues in BRCEmbargo.m
- Added missing import for `BRCArtObject.h`
- Removed duplicate import of `BRCEventObject.h`

### 2. Updated Embargo Logic
Modified `canShowLocationForObject:` method to:
- Comment out the combined check for camps, events, and art
- Keep only the art embargo check active
- Added warning pragma for 2026 re-enablement

## Technical Details

### File Modifications

#### `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/BRCEmbargo.m`

**Before:**
```objc
#import "BRCEventObject.h"
#import "BRCCampObject.h"
#import "BRCEventObject.h"  // duplicate

+ (BOOL)canShowLocationForObject:(BRCDataObject *)dataObject
{
    if (![BRCEmbargo allowEmbargoedData]) {
        if ([dataObject isKindOfClass:[BRCCampObject class]] || [dataObject isKindOfClass:[BRCEventObject class]] ||
            [dataObject isKindOfClass:[BRCArtObject class]]) {
            return NO;
        }
        if ([dataObject isKindOfClass:[BRCArtObject class]]) {
            return NO;
        }
    }
    return YES;
}
```

**After:**
```objc
#import "BRCEventObject.h"
#import "BRCCampObject.h"
#import "BRCArtObject.h"  // fixed import

#warning TODO: Re-enable camp and event embargo for 2026 by uncommenting the code block below
+ (BOOL)canShowLocationForObject:(BRCDataObject *)dataObject
{
    if (![BRCEmbargo allowEmbargoedData]) {
//        if ([dataObject isKindOfClass:[BRCCampObject class]] || [dataObject isKindOfClass:[BRCEventObject class]] ||
//            [dataObject isKindOfClass:[BRCArtObject class]]) {
//            return NO;
//        }
        if ([dataObject isKindOfClass:[BRCArtObject class]]) {
            return NO;
        }
    }
    return YES;
}
```

## Expected Outcomes

### What Now Works:
- **Camp Locations**: Displayed immediately, even before gates open
- **Event Locations**: Displayed immediately, even before gates open
- **Art Locations**: Remain embargoed until gates open or passcode entry

### For 2026:
To re-enable the full embargo next year:
1. Uncomment the commented code block in `canShowLocationForObject:`
2. Remove or update the warning pragma
3. Test that all three types (camps, events, art) are properly embargoed

## Testing Verification
- Build completed successfully with no compilation errors
- The warning pragma will appear in Xcode's warning list as a reminder

## Notes
- The duplicate art check in the original code was intentional and has been preserved
- The commented code preserves the exact original logic for easy restoration
- This change affects all views that display location data: maps, detail views, and table cells