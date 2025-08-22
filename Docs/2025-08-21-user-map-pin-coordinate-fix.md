# User Map Pin Coordinate Saving Fix
Date: 2025-08-21

## Problem Statement
User map pins and favorites were resetting to Man coordinates (40.786969, -119.204101) when the app was force quit and relaunched. The dragged coordinates were not being persisted to the database.

## Root Cause
MapLibre doesn't have a `didDrag` delegate method like Mapbox. While it uses a drag state mechanism via `setDragState`, we weren't capturing when dragging ended to save the updated coordinates.

## Solution Implemented
Added a closure callback to `ImageAnnotationView` that fires when dragging ends, allowing `UserMapViewAdapter` to save the updated coordinates immediately.

### Files Modified

#### 1. ImageAnnotationView.swift
- Added `onDragEnded: ((MLNAnnotation) -> Void)?` property
- Modified `setDragState` to call the closure when drag state is `.ending`

```swift
// Added property
var onDragEnded: ((MLNAnnotation) -> Void)?

// Modified case in setDragState
case .ending, .canceling:
    endDragging()
    if case .ending = dragState, let annotation = annotation {
        onDragEnded?(annotation)
    }
```

#### 2. UserMapViewAdapter.swift  
- Set the `onDragEnded` closure when configuring user map points
- Closure saves the map point with updated coordinates

```swift
if point is BRCUserMapPoint {
    imageAnnotationView.isDraggable = true
    imageAnnotationView.isUserInteractionEnabled = true
    imageAnnotationView.addLongPressGestureIfNeeded(...)
    imageAnnotationView.onDragEnded = { [weak self] annotation in
        if let mapPoint = annotation as? BRCMapPoint {
            self?.saveMapPoint(mapPoint)
        }
    }
}
```

## Technical Details

### MapLibre Drag State Flow
1. User long presses annotation → state changes to `.starting`
2. User drags → state changes to `.dragging`  
3. User releases → state changes to `.ending`
4. MapLibre automatically updates the annotation's coordinate property
5. Our closure fires and saves the updated coordinate to YapDatabase

### Key Insights
- MapLibre automatically updates the annotation's coordinate when dragging
- The coordinate is available in the annotation when drag state is `.ending`
- Using a closure avoids tight coupling compared to notifications
- Weak self reference prevents retain cycles

## Testing Required
1. Create a new user pin
2. Drag it to a new location
3. Force quit the app (swipe up and remove from app switcher)
4. Relaunch the app
5. Verify the pin remains at the dragged location

## Update: KVO Crash Fix

### Additional Problem Discovered
After implementing the drag-end save feature, a KVO crash occurred:
```
Thread 1: "Cannot remove an observer <BRCMapView> for the key path "coordinate" 
from <BRCUserMapPoint> because it is not registered as an observer."
```

### Root Cause
The `saveMapPoint` method was calling both:
1. `clearEditingAnnotation()` which removes the annotation
2. `mapView.removeAnnotation(mapPoint)` which tries to remove it again

This double removal caused MapLibre to try removing KVO observers twice, causing a crash.

### Solution
1. Modified `saveMapPoint` to check if the mapPoint is the editing annotation:
   - If it is, only call `clearEditingAnnotation()` 
   - If it's not (e.g., dragged without editing), remove it normally

2. Made `clearEditingAnnotation` idempotent (safe to call multiple times):
   - Sets `editingAnnotation = nil` before removing the annotation
   - Guards against nil to return early if already cleared
   - Prevents crashes when called from multiple code paths (drag end, cancel, save)

## Update: Race Condition Fix with Long-Lived Read Transaction

### Additional Problem Discovered  
After fixing the KVO crash, a race condition appeared where pins would show at old locations after dragging because:
1. `saveMapPoint` writes to `readWriteConnection` (synchronous)
2. `reloadAnnotations()` reads from `YapCollectionAnnotationDataSource` 
3. That datasource uses `uiConnection` with a long-lived read transaction
4. With WAL mode, the uiConnection reads from a stable checkpoint and doesn't see the write yet

### Solution
Created a separate save path for drag operations that bypasses the problematic reload:
- Modified `onDragEnded` closure to save directly to database
- Doesn't remove or reload the annotation (MapLibre already has correct coordinates)
- Avoids the race condition entirely

## Update: Delete Race Condition Fix

### Problem
Similar to the save race condition, delete also had issues where the pin wouldn't disappear from the map immediately because `reloadAnnotations()` was reading from the stale `uiConnection`.

### Solution  
Modified `deleteMapPoint` to skip the reload:
- Remove the annotation from the map immediately
- Don't call `reloadAnnotations()` which would read from stale connection
- The UI update happens immediately while the database deletion is persisted

## Summary of All Fixes
1. ✅ Coordinate saving when dragging - Added `onDragEnded` closure
2. ✅ KVO crash prevention - Made `clearEditingAnnotation` idempotent
3. ✅ Save race condition - Direct save for drag, skip reload
4. ✅ Cancel button - Now does nothing (user fixed)
5. ✅ Delete race condition - Remove immediately, skip reload

## Remaining Issues
1. Duplicate annotations may be added when editing existing pins
2. Alert shows even when just dragging (not editing title)

## Related Files
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/BRCMapPoint.m` - Base map point class
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/BRCUserMapPoint.h` - User map point subclass
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/MainMapViewController.swift` - Creates new pins