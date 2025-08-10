# Favorites Heart Icon on Map Implementation

## High-Level Plan

**Problem Statement**: Add visual indicator for favorited items on the map when using emoji icons, similar to how event status is displayed with colored dots.

**Solution Overview**: Implement a heart icon overlay that appears on the bottom-right corner of emoji map markers when an item is favorited.

**Key Changes**:
1. Extended EmojiImageRenderer to support favorite status
2. Modified marker generation to check favorite status from database
3. Removed legacy pink pin fallback for favorites

## Technical Details

### File Modifications

#### 1. EmojiImageRenderer.swift
- Added `isFavorite` and `heartSize` properties to Configuration struct
- Updated cache key to include favorite status
- Added heart rendering logic using SF Symbol "heart.fill"
- Heart positioned at bottom-right corner with 2pt offset
- Using .systemPink color for consistency with app theme
- No background circle - transparent overlay for cleaner appearance

#### 2. BRCDataObject+EmojiMarker.swift
- Added database read to check favorite status from metadata
- Pass `isFavorite` flag to all emoji renderer configurations
- Supports simultaneous display of event status dots (top-left) and heart (bottom-right)

#### 3. AnnotationDataSource.swift
- Removed fallback to pink pin image for favorites (lines 191-195)
- All favorite indication now handled by emoji renderer

### Implementation Approach

The implementation follows the existing pattern for event status dots but positions the heart in the opposite corner. This allows:
- Events to show both status indicator (green/orange/red dot) and favorite heart
- All object types (art, camps, events) to display heart when favorited
- Efficient caching with favorite status included in cache key

### Code Snippets

**Configuration Structure Update**:
```swift
struct Configuration {
    // ... existing properties ...
    let isFavorite: Bool
    let heartSize: CGFloat
}
```

**Heart Rendering Logic**:
```swift
if configuration.isFavorite {
    let heartImage = UIImage(systemName: "heart.fill")
    let heartTintColor = UIColor.systemPink
    let heartOffset: CGFloat = 2
    
    let heartRect = CGRect(
        x: configuration.size.width - configuration.heartSize - heartOffset,
        y: configuration.size.height - configuration.heartSize - heartOffset,
        width: configuration.heartSize,
        height: configuration.heartSize
    )
    
    heartTintColor.setFill()
    heartImage?.draw(in: heartRect)
}
```

**Database Integration**:
```swift
var isFavorite = false
BRCDatabaseManager.shared.uiConnection.read { transaction in
    let metadata = self.metadata(with: transaction)
    isFavorite = metadata.isFavorite
}
```

## Build and Test Results

Successfully built the application with no errors. The implementation:
- Compiles without warnings
- Integrates cleanly with existing emoji marker system
- Maintains backwards compatibility with non-emoji pin modes

## Expected Outcomes

After this implementation:
- ✅ Favorited items show pink heart icon on bottom-right of emoji
- ✅ Events can display both status dot and heart simultaneously
- ✅ Heart appears/disappears when toggling favorites
- ✅ Clean appearance without background circles
- ✅ Consistent with existing app UI patterns

## Dependencies

- UIKit SF Symbols for heart icon
- Existing EmojiImageRenderer caching system
- YapDatabase for favorite status persistence
- BRCObjectMetadata for favorite state management

## Future Considerations

- May need to refresh map annotations when favorite status changes
- Could add animation for heart appearance/disappearance
- Consider cache invalidation strategy for favorite changes