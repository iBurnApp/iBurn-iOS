# 2025-07-16 Fix Detail Map Zoom Functionality

## High-Level Plan
**Problem**: The SwiftUI DetailMapViewRepresentable was missing the automatic map zoom functionality that shows both user location and destination coordinate simultaneously. This was present in the old Objective-C implementation but was lost during the SwiftUI rewrite.

**Solution**: Moved annotation setup and zoom logic from `makeUIView` to `updateUIView` to follow proper SwiftUI patterns and ensure the map always zooms to show both user and destination locations.

## Technical Details

### Key Changes Made

#### 1. Clean Separation in makeUIView
**File**: `iBurn/Detail/Views/DetailMapViewRepresentable.swift:18-28`

**Before**: `makeUIView` created annotation, data source, adapter, and stored references (side effects)

**After**: Clean view creation with no side effects:
```swift
func makeUIView(context: Context) -> MLNMapView {
    // Create map view with iBurn defaults (no side effects)
    let mapView = MLNMapView.brcMapView()
    mapView.isUserInteractionEnabled = false
    
    // Add tap gesture recognizer for navigation
    let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap))
    mapView.addGestureRecognizer(tapGesture)
    
    return mapView
}
```

#### 2. Reactive updateUIView Implementation
**File**: `iBurn/Detail/Views/DetailMapViewRepresentable.swift:30-47`

**Before**: Empty method with comment "Map content is static for detail views, no updates needed"

**After**: Fully reactive implementation:
```swift
func updateUIView(_ uiView: MLNMapView, context: Context) {
    // Always update annotation when called (handles data changes)
    guard let annotation = DataObjectAnnotation(object: dataObject, metadata: metadata ?? BRCObjectMetadata()) else {
        return
    }
    
    // Create fresh data source and adapter for current data
    let dataSource = StaticAnnotationDataSource(annotation: annotation)
    let mapViewAdapter = MapViewAdapter(mapView: uiView, dataSource: dataSource)
    mapViewAdapter.reloadAnnotations()
    context.coordinator.mapViewAdapter = mapViewAdapter
    
    // Always perform zoom for current data
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        let padding = UIEdgeInsets(top: 45, left: 45, bottom: 45, right: 45)
        uiView.brc_showDestination(for: dataObject, metadata: metadata ?? BRCObjectMetadata(), animated: true, padding: padding)
    }
}
```

### Context Preservation

#### Missing Functionality
The original Objective-C implementation in `BRCDetailViewController.m:184-187` had:
```objc
dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    UIEdgeInsets padding = UIEdgeInsetsMake(45, 45, 45, 45);
    [self.mapView brc_showDestinationForDataObject:self.dataObject metadata:self.metadata animated:NO padding:padding];
});
```

This crucial zoom functionality was completely missing from the SwiftUI implementation.

#### Root Cause
The `brc_showDestination` method from `MLNMapView+iBurn.m` performs the critical zoom logic:
1. Gets user location (or defaults to Black Rock City center if outside region)
2. Creates coordinate array with both destination and user coordinates
3. Calls `setVisibleCoordinates` to zoom map to show both points
4. Handles edge cases like user being outside Burning Man region

#### Decision Rationale
- **Proper SwiftUI patterns**: `makeUIView` only creates, `updateUIView` handles state
- **Reactive to data changes**: If dataObject changes (PageViewController), map updates automatically
- **Matches original behavior**: Same 0.1s delay, same padding (45px), calls same zoom method
- **Smooth transitions**: Uses `animated: true` for subsequent updates

### Key Implementation Details

#### SwiftUI UIViewRepresentable Best Practices
- **makeUIView**: Pure view creation, no side effects, no state changes
- **updateUIView**: Handles all state updates, called by SwiftUI when needed
- **Coordinator**: Manages gesture handling and retains references

#### Timing and Animation
- **0.1s delay**: Ensures MapLibre is ready (matches original Objective-C timing)
- **45px padding**: Same as original `UIEdgeInsetsMake(45, 45, 45, 45)`
- **animated: true**: Smooth zoom transitions for updates

#### Data Handling
- **Always refresh**: Creates fresh annotation/adapter on every update
- **Handles optionals**: Uses `metadata ?? BRCObjectMetadata()` for nil safety
- **Reactive**: Responds to any dataObject or metadata changes

## Expected Outcomes

### What Works After Implementation
- ✅ DetailView map now automatically zooms to show both user location and destination
- ✅ Map updates reactively if dataObject changes (e.g., PageViewController navigation)
- ✅ Follows proper SwiftUI UIViewRepresentable patterns
- ✅ Maintains existing tap-to-navigate functionality
- ✅ Respects embargo restrictions via existing shouldShowMap logic
- ✅ Build succeeds without errors

### Verification Commands
```bash
# Build project
mcp__XcodeMCP__xcode_build --xcodeproj /Users/chrisbal/Documents/Code/iBurn-iOS/iBurn.xcworkspace --scheme iBurn --destination "iPhone 16 Pro"
```

### Files Modified
1. `iBurn/Detail/Views/DetailMapViewRepresentable.swift` - Moved annotation setup and zoom logic to updateUIView

## Cross-References
This work fixes functionality that was lost during the SwiftUI detail view rewrite documented in `2025-07-13-detail-screen-fixes.md`. The map integration was added but was missing the critical zoom functionality that users expected from the original implementation.

## Additional Context
The zoom functionality is crucial for user experience because:
- **Spatial context**: Users need to see their location relative to the destination
- **Navigation planning**: Showing both points helps users understand distance and direction
- **Familiar behavior**: Users expect this from the original app implementation
- **Burning Man context**: The playa is large and users need spatial orientation