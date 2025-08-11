# 2025-08-10 Event Type Detail Display

## High-Level Plan

**Problem**: Event detail screen didn't show the event type, making it unclear what category of event users were viewing.

**Solution**: Added event type as a dedicated section with header "EVENT TYPE", positioned before the host description for clear event categorization.

## Technical Details

### Changes Made

#### 1. Added Event Type Cell Case
**File**: `iBurn/Detail/Models/DetailCellType.swift`
```swift
case eventType(BRCEventType)
```

#### 2. Added Event Type to Event Cells
**File**: `iBurn/Detail/ViewModels/DetailViewModel.swift`
```swift
// Event type section
cells.append(.eventType(event.eventType))
```
Positioned after location, before host description.

#### 3. Created DetailEventTypeCell Component
**File**: `iBurn/Detail/Views/DetailView.swift`
```swift
struct DetailEventTypeCell: View {
    let eventType: BRCEventType
    @Environment(\.themeColors) var themeColors
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("EVENT TYPE")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(themeColors.detailColor)
                .textCase(.uppercase)
            
            Text("\(eventType.emoji) \(eventType.displayString)")
                .foregroundColor(themeColors.secondaryColor)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
```

#### 4. Added Switch Cases
- Added case handling in cell rendering switch
- Added eventType to non-tappable cells list

### Display Format

The event type now appears:
- **Section Header**: "EVENT TYPE" in uppercase, caption font
- **Content**: `[emoji] [display string]` in secondary color
- **Style**: Consistent with other section headers (SCHEDULE, LANDMARK, etc.)
- **Examples**:
  - "🎉 Gathering/Party"
  - "🧑‍🏫 Class/Workshop"
  - "💃 Performance"

### Cell Order

The event type appears in this order within event details:
1. Image (if available)
2. Title
3. Description
4. Host relationship (camp/art)
5. Next event from host
6. Schedule
7. Location
8. **EVENT TYPE (with section header)**
9. Host description

### Visual Consistency

The implementation maintains consistency with other detail sections:
1. Uses standard section header styling (uppercase, caption, semibold)
2. Follows same VStack layout pattern as LANDMARK and SCHEDULE
3. Uses theme colors appropriately (detailColor for header, secondaryColor for content)
4. Proper spacing and alignment

## Context Preservation

### Event Type System
- Event types are defined in `BRCEventObject.h` as an enum `BRCEventType`
- Display strings and emojis are mapped in `BRCEventObject.swift` extensions
- Each type has:
  - Emoji representation (e.g., 🎉 for Party)
  - Display string (e.g., "Gathering/Party")
  - Visibility flag (some types are hidden)

### Integration Points
- Uses existing `.text` cell type with `.subtitle` style
- Leverages BRCEventType extensions for display formatting
- No new UI components required
- Works with existing theme color system

## Expected Outcomes

Users viewing event details will now see:
- Clear indication of event type at the top of details
- Visual emoji representation for quick recognition
- Descriptive text for accessibility and clarity
- Consistent theming with rest of detail view

## Testing Verification

- Build completed successfully
- Event type displays correctly with emoji and text
- Cell positioning is logical and prominent
- No UI layout issues introduced