# Fix Camp Landmark and Frontage Display

## Problem Statement
The new SwiftUI detail screen was missing the **landmark** and **frontage** fields for camps. These fields existed in the `BRCCampObject` data model but weren't being displayed in the new implementation.

## Solution Overview
Added the missing landmark and frontage fields to the camp detail view by modifying the `generateCampCells` method in `DetailViewModel.swift`.

## Technical Details

### File Modifications
**File**: `/Users/chrisbal/Documents/Code/iBurn-iOS-2/iBurn/Detail/ViewModels/DetailViewModel.swift`

**Method**: `generateCampCells(_ camp: BRCCampObject) -> [DetailCellType]`

### Code Changes
Added two new cell types to display camp landmark and frontage:

```swift
// Landmark
if let landmark = camp.landmark, !landmark.isEmpty {
    cells.append(.text("Landmark: \(landmark)", style: .caption))
}

// Frontage (only show when embargo allows)
if dataService.canShowLocation(for: camp), 
   let frontage = camp.frontage, !frontage.isEmpty {
    cells.append(.text("Frontage: \(frontage)", style: .caption))
}
```

### Key Implementation Details
1. **Landmark** - Always displayed if the camp has a landmark value
2. **Frontage** - Only displayed when:
   - The embargo allows location data (`dataService.canShowLocation(for: camp)`)
   - The camp has a frontage value

### Field Order
The fields are displayed in this order:
1. Hometown
2. Landmark (new)
3. Frontage (new, if embargo allows)
4. Location/Playa Address

## Context Preservation

### Investigation Process
1. Found that `BRCCampObject` has these properties:
   - `landmark` (NSString)
   - `frontage` (NSString)
   - Also: `intersection`, `intersectionType`, `dimensions`, `exactLocation`

2. Discovered from `BRCDetailCellInfo.m` that:
   - Landmark was shown as a regular text cell
   - Frontage was shown only when embargo data was allowed

3. The new SwiftUI implementation in `DetailViewModel.swift` was missing these fields entirely

### Additional Camp Properties Not Implemented
While investigating, found other camp properties that could potentially be added:
- `intersection`
- `intersectionType` 
- `dimensions`
- `exactLocation`

These weren't shown in the old detail view either, so they weren't added in this fix.

## Expected Outcomes
After this implementation:
- Camp detail screens will now show the landmark field (e.g., "Landmark: Giant pink flamingo")
- Camp detail screens will show the frontage field when location data is allowed (e.g., "Frontage: Esplanade")
- The display order maintains logical grouping of location-related information

## Related Work Sessions
- 2025-07-12-detail-view-swiftui-rewrite.md - Original SwiftUI detail view implementation
- 2025-07-13-detail-screen-fixes.md - Previous detail screen fixes