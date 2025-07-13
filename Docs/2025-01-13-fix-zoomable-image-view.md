# Fix ZoomableImageView Centering and Zoom Issues

Date: 2025-01-13

## Summary

Fixed critical issues with ZoomableImageView that were causing runtime errors and preventing the image from displaying properly. The view now correctly centers images, scales them to fit the container width, and provides smooth 2x zoom on double-tap.

## Problems Identified

1. **Zero scale error**: "_clampedZoomScale:allowRubberbanding: Must be called with non-zero scale"
2. **State modification warning**: "Modifying state during view update, this will cause undefined behavior"
3. **Image not appearing**: Image view wasn't visible on initial presentation
4. **Incorrect centering**: Image appeared at top of view instead of centered

## Root Causes

- `updateUIView` was being called before the scroll view had valid bounds (zero size)
- Direct state mutation in `scrollViewDidZoom` delegate callback conflicted with SwiftUI's update cycle
- Initial setup was attempting calculations with zero-sized bounds
- Missing proper layout timing handling

## Solution Implemented

### 1. Added Bounds Validation
- Added guard checks to ensure scroll view has valid bounds before calculations
- Deferred zoom scale setup until after first layout pass
- Used `needsInitialSetup` flag to track initialization state

### 2. Fixed State Modification Warning
- Wrapped `isZoomed` state updates in `DispatchQueue.main.async`
- Only updates state when value actually changes
- Prevents SwiftUI update conflicts during delegate callbacks

### 3. Rewrote Initialization Sequence
- Set initial image view frame based on image size
- Configure initial content size immediately
- Defer zoom calculations until bounds are valid

### 4. Improved Centering Logic
- Use frame-based centering instead of constraints
- Adjust image view frame directly based on scroll view bounds
- Center both horizontally and vertically when image is smaller than container

### 5. Updated Zoom Behavior
- Changed maximum zoom from 3x to 2x as requested
- Zoom to tapped point on double-tap
- Smooth animation between zoom levels

## Key Code Changes

```swift
// Added bounds validation in updateUIView
func updateUIView(_ uiView: UIScrollView, context: Context) {
    // Only update if we have valid bounds
    if uiView.bounds.size.width > 0 && uiView.bounds.size.height > 0 {
        context.coordinator.setupZoomScaleIfNeeded()
    }
}

// Async state updates to avoid SwiftUI conflicts
func scrollViewDidZoom(_ scrollView: UIScrollView) {
    centerImageIfNeeded()
    
    let isCurrentlyZoomed = scrollView.zoomScale > scrollView.minimumZoomScale
    if parent.isZoomed != isCurrentlyZoomed {
        DispatchQueue.main.async { [weak self] in
            self?.parent.isZoomed = isCurrentlyZoomed
        }
    }
}

// Frame-based centering
func centerImageIfNeeded() {
    guard let scrollView = self.scrollView,
          let imageView = self.imageView else { return }
    
    let scrollViewSize = scrollView.bounds.size
    var frameToCenter = imageView.frame
    
    // Center horizontally
    if frameToCenter.size.width < scrollViewSize.width {
        frameToCenter.origin.x = (scrollViewSize.width - frameToCenter.size.width) / 2
    } else {
        frameToCenter.origin.x = 0
    }
    
    // Center vertically
    if frameToCenter.size.height < scrollViewSize.height {
        frameToCenter.origin.y = (scrollViewSize.height - frameToCenter.size.height) / 2
    } else {
        frameToCenter.origin.y = 0
    }
    
    imageView.frame = frameToCenter
}
```

## Testing Notes

The implementation now:
- Shows the image immediately on presentation
- Centers the image properly within the container
- Scales to fit the width of the container
- Provides smooth 2x zoom on double-tap
- Zooms to the tapped location
- No longer produces runtime errors or warnings
- Properly disables swipe-to-dismiss when zoomed

## Files Modified

- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/Detail/Views/ZoomableImageView.swift` - Complete rewrite of zoom handling

## Future Considerations

- Could add pinch-to-zoom gesture for more precise control
- Consider adding a loading indicator for large images
- Might want to add support for different content modes (fit vs fill)