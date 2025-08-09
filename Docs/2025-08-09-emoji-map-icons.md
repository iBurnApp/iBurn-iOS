# Emoji Map Icons Implementation

## Date: 2025-08-09

## Overview
Implemented emoji-based map icons for the iBurn app as an alternative to the traditional colored pin markers. This feature allows users to quickly identify different types of points of interest on the map using familiar emoji symbols.

## Problem Statement
The existing map used generic colored pins (blue for art, purple for camps, various colors for events based on timing) which didn't immediately convey what type of location each pin represented.

## Solution
Created a toggleable emoji map icon system that:
- Shows type-specific emoji for each location
- Maintains timing information for events with colored borders
- Can be enabled/disabled via user preference
- Preloads common emojis for performance

## Implementation Details

### Files Created

1. **EmojiImageRenderer.swift**
   - Utility class that converts emoji strings to UIImage
   - Supports configurable size, background color, and borders
   - Implements caching for performance
   - Preloads common emojis on app launch

2. **BRCArtObject+Emoji.swift**
   - Extension adding emoji property to art objects
   - Returns 🎨 for all art installations

3. **BRCCampObject+Emoji.swift**
   - Extension adding emoji property to camp objects
   - Returns ⛺ for all camps

4. **BRCDataObject+EmojiMarker.swift**
   - Core extension managing emoji marker generation
   - UserDefaults key for preference storage
   - Notification system for setting changes
   - Event status color support

### Files Modified

1. **BRCDataObject.m**
   - Updated `brc_markerImage` to check emoji preference
   - Falls back to traditional pins if emoji rendering fails

2. **AppearanceViewController.swift**
   - Added new "Map Icons" section with toggle
   - Handles preference changes and posts notifications

3. **BaseMapViewController.swift**
   - Added notification observer for emoji setting changes
   - Reloads annotations when preference changes

4. **AppDelegate.swift**
   - Added background preloading of common emojis on launch

## Emoji Mappings

### Core Types
- **Art**: 🎨 (art palette)
- **Camps**: ⛺ (tent)
- **Events**: Based on event type (already defined in BRCEventObject.swift)

### Event Types (Existing)
- Workshop: 🧑‍🏫
- Performance: 💃
- Support: 🏥
- Party: 🎉
- Ceremony: 🔮
- Game: 🎯
- Fire: 🔥
- Adult: 🔞
- Kids: 👨‍👩‍👧‍👦
- Parade: 🎏
- Food: 🍔
- Crafts: 🎨
- Live Music: 🎺
- And more...

### Event Status Indication
Events maintain their timing-based colors:
- Green border: Currently happening or starting soon
- Orange border: Ending soon
- Red border: Already ended
- No border: Future event

## User Experience

1. Navigate to Settings → Appearance
2. Find "Map Icons" section
3. Toggle "Use Emoji Map Icons" switch
4. Map immediately refreshes with new icons
5. Preference persists across app launches

## Performance Considerations

1. **Caching**: All rendered emojis are cached using NSCache
2. **Preloading**: Common emojis preloaded on app launch
3. **Background Processing**: Preloading happens on background queue
4. **Fallback**: Gracefully falls back to pins if rendering fails

## Testing Notes

The build currently has compilation issues that need to be resolved:
1. New Swift files need to be added to the Xcode project target
2. May need to import the bridging header properly

## Next Steps

1. Add the new Swift files to the Xcode project:
   - Open iBurn.xcworkspace in Xcode
   - Right-click on iBurn folder
   - Add Files to "iBurn"
   - Select all 4 new Swift files
   - Ensure "iBurn" target is selected

2. Test the feature:
   - Build and run on simulator
   - Navigate to Appearance settings
   - Toggle emoji map icons
   - Verify map updates correctly
   - Check performance with many annotations

3. Potential Enhancements:
   - Add more specific emojis based on camp services
   - Custom emoji for special locations (Man, Temple)
   - User-selectable emoji themes
   - Accessibility considerations for emoji visibility

## Technical Debt
- Consider using SF Symbols as alternative/supplement
- Optimize rendering for very large numbers of annotations
- Add unit tests for emoji rendering
- Consider dark mode emoji visibility