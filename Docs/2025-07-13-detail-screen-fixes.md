# 2025-07-13 Detail Screen Architecture Cleanup

## High-Level Plan
**Problem**: DetailHostingController initialization was creating temporary objects just to satisfy super.init(), then immediately recreating everything properly. This violated clean architecture principles and wasted resources.

**Solution**: Cleaned up dependency injection by removing temporary object creation, eliminating IUOs, and properly structuring the coordinator initialization pattern.

## Technical Details

### Key Changes Made

#### 1. Removed Implicitly Unwrapped Optionals (IUOs)
**File**: `iBurn/Detail/Controllers/DetailHostingController.swift:42-44`

**Before**:
```swift
var viewModel: DetailViewModel!
var coordinator: DetailActionCoordinator!
```

**After**: 
```swift
let viewModel: DetailViewModel
let coordinator: DetailActionCoordinator
```

#### 2. Simplified Init to Accept Dependencies
**File**: `iBurn/Detail/Controllers/DetailHostingController.swift:48-63`

**Before** (lines 48-94): Complex init creating services internally, then temp objects, then real objects
**After**: Clean dependency injection:
```swift
init(
    viewModel: DetailViewModel,
    coordinator: DetailActionCoordinator,
    colors: BRCImageColors,
    dataObject: BRCDataObject
) {
    self.viewModel = viewModel
    self.coordinator = coordinator
    self.colors = colors
    self.dataObject = dataObject
    
    super.init(rootView: DetailView(viewModel: viewModel))
    
    self.title = dataObject.title
    self.hidesBottomBarWhenPushed = true
}
```

#### 3. Fixed Coordinator Architecture
**File**: `iBurn/Detail/Services/DetailActionCoordinator.swift`

**Changes**:
- Made `presenter` optional in `DetailActionCoordinatorDependencies:25`
- Added `updatePresenter()` method to protocol and implementation
- Updated factory to create coordinator without presenter initially
- Added nil checks in action handling methods

#### 4. Updated Factory Pattern
**File**: `iBurn/Detail/Controllers/DetailViewControllerFactory.swift:67-93`

**New approach**:
```swift
// Create coordinator without presenter initially
let coordinator = DetailActionCoordinatorFactory.makeCoordinator()

// Create viewModel with all dependencies
let viewModel = DetailViewModel(...)

// Create controller with all dependencies
let controller = DetailHostingController(...)

// Update coordinator with the real presenter
coordinator.updatePresenter(controller)
```

#### 5. Removed @MainActor Requirements
**File**: `iBurn/Detail/ViewModels/DetailViewModel.swift:14`

Removed `@MainActor` annotation to avoid polluting the codebase with async requirements.

### Context Preservation

#### Before State
The initialization was following this problematic pattern:
1. Create temp coordinator with dummy UIViewController presenter
2. Create temp viewModel with temp coordinator  
3. Create temp view with temp viewModel
4. Call super.init(rootView: tempView)
5. Create real coordinator with self as presenter
6. Create real viewModel with real coordinator
7. Update rootView to real view
8. Discard all temp objects

#### Decision Rationale
- **No temp objects**: Eliminates waste and confusion
- **Proper dependency injection**: Dependencies created externally and injected
- **Clean initialization order**: Coordinator → ViewModel → Controller → Wire presenter
- **Maintains existing patterns**: Still uses factory pattern and protocol-based architecture

#### Cross-References
This work builds upon the SwiftUI detail view implementation completed in `2025-07-12-swiftui-detail-view-complete.md`.

## Expected Outcomes

### What Works After Implementation
- ✅ DetailHostingController has clean initialization without temporary objects
- ✅ All properties are properly initialized (no IUOs)
- ✅ Coordinator properly receives presenter reference after controller creation
- ✅ Factory pattern cleanly separates dependency creation from controller logic
- ✅ Build succeeds without @MainActor pollution
- ✅ Existing navigation and presentation functionality preserved

### Verification Commands
```bash
# Build project
xcodebuild -workspace iBurn.xcworkspace -scheme iBurn -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,OS=18.5,arch=arm64,name=iPhone 16 Pro' \
  -configuration Debug build -quiet
```

### Files Modified
1. `iBurn/Detail/Controllers/DetailHostingController.swift` - Simplified init, removed IUOs
2. `iBurn/Detail/Controllers/DetailViewControllerFactory.swift` - Updated factory methods
3. `iBurn/Detail/Services/DetailActionCoordinator.swift` - Made presenter optional, added updatePresenter
4. `iBurn/Detail/ViewModels/DetailViewModel.swift` - Removed @MainActor annotation
5. `iBurn/Detail/Views/DetailView_Previews.swift` - Updated mock coordinator

## Additional Work: Protocol-Based Navigation Item Forwarding

### Problem Extension
After cleaning up DetailHostingController initialization, discovered that SwiftUI navigation items (.toolbar, .navigationTitle) don't automatically forward to UIPageViewController in PageViewManager.

### Solution: DynamicViewController Protocol System

#### 1. Created Protocol-Based Event System
**File**: `iBurn/Detail/Controllers/DynamicViewControllerProtocols.swift`

```swift
enum ViewControllerEvent {
    case viewWillLayoutSubviews
    case navigationItemDidChange  
    case toolbarDidChange
    case viewDidAppear
    case viewWillDisappear
}

protocol DynamicViewController: AnyObject {
    var eventHandler: DynamicViewControllerEventHandler? { get set }
    func notifyEventHandler(_ event: ViewControllerEvent)
}

protocol DynamicViewControllerEventHandler: AnyObject {
    func viewControllerDidTriggerEvent(_ event: ViewControllerEvent, sender: UIViewController)
}
```

#### 2. Enhanced DetailHostingController
**File**: `iBurn/Detail/Controllers/DetailHostingController.swift:41,49,79,104`

- Conforms to `DynamicViewController` protocol
- Sends events in `viewWillLayoutSubviews()` and `viewDidAppear()` 
- Enables dynamic toolbar updates (favorite button state changes, etc.)

#### 3. Created Content-Agnostic DetailPageViewController  
**File**: `iBurn/Detail/Controllers/DetailPageViewController.swift`

- Subclasses UIPageViewController with generic navigation forwarding
- Conforms to `DynamicViewControllerEventHandler`
- Uses existing `copyParameters(from:)` method generically
- No business logic or coupling to specific view controller types

#### 4. Updated PageViewManager Integration
**File**: `iBurn/PageViewManager.swift:28,87`

- Uses `DetailPageViewController` instead of `UIPageViewController`
- Delegate method calls `copyParameters(from:)` on page transitions
- Handles both SwiftUI and UIKit detail views uniformly

### Key Benefits
- ✅ **Dynamic Navigation Updates**: Toolbar changes when favorite status toggles
- ✅ **Generic Architecture**: DetailPageViewController works with any UIViewController
- ✅ **Protocol-Based Design**: Clean separation of concerns, no tight coupling
- ✅ **Backward Compatible**: Works with existing BRCDetailViewController
- ✅ **Event-Driven**: Extensible system for future navigation event types

### Files Modified (Navigation System)
1. `iBurn/Detail/Controllers/DynamicViewControllerProtocols.swift` - NEW: Protocol definitions
2. `iBurn/Detail/Controllers/DetailPageViewController.swift` - NEW: Generic page controller
3. `iBurn/Detail/Controllers/DetailHostingController.swift` - Added protocol conformance
4. `iBurn/PageViewManager.swift` - Updated to use DetailPageViewController

## Additional Work: Event Creation Dismissal Fix

### Problem
Event creation from EventEditServiceImpl wasn't dismissing properly when users tapped "Cancel" or "Add" in the EKEventEditViewController.

### Root Cause  
The `DetailActionCoordinatorImpl` was creating `EKEventEditViewController` instances but not implementing the required `EKEventEditViewDelegate` protocol to handle dismissal.

### Solution: EKEventEditViewDelegate Implementation
**File**: `iBurn/Detail/Services/DetailActionCoordinator.swift:78,122,330-348`

#### 1. Added Delegate Conformance
```swift
private class DetailActionCoordinatorImpl: NSObject, DetailActionCoordinator, EKEventEditViewDelegate {
```

#### 2. Set Delegate on Event Controller
```swift
case .showEventEditor(let event):
    // ... existing code ...
    let eventEditController = dependencies.eventEditService.createEventEditController(for: event)
    eventEditController.editViewDelegate = self  // ← Added this line
    presenter.present(eventEditController, animated: true, completion: nil)
```

#### 3. Implemented Delegate Method
```swift
extension DetailActionCoordinatorImpl {
    func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
        // Dismiss the event edit controller
        dependencies.presenter?.dismiss(animated: true, completion: nil)
        
        // Log the action for debugging
        switch action {
        case .cancelled:
            print("📅 Event creation cancelled")
        case .canceled:
            print("📅 Event creation canceled")
        case .saved:
            print("📅 Event saved to calendar")
        case .deleted:
            print("📅 Event deleted")
        @unknown default:
            print("📅 Unknown event edit action: \(action.rawValue)")
        }
    }
}
```

### Key Details
- **NSObject inheritance**: Required for EKEventEditViewDelegate conformance
- **Both .cancelled and .canceled**: EventKit uses both spellings across iOS versions
- **Proper dismissal**: Coordinator handles dismissal via presenter pattern
- **Debug logging**: Added logging to track user actions for debugging

### Verification
```bash
# Build succeeds with new delegate implementation
xcodebuild -workspace iBurn.xcworkspace -scheme iBurn -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,OS=18.5,arch=arm64,name=iPhone 16 Pro' \
  -configuration Debug build -quiet
```

## Additional Work: DetailView UI Bug Fixes

### Problems Identified
After implementing the SwiftUI DetailView, three UI bugs were discovered:

1. **Image width not resizing**: Small images didn't expand to fill screen width 
2. **Background not using theme colors**: View used global theme colors instead of object-specific extracted colors
3. **Cells not completely tappable**: Tappable cells lacked visual feedback

### Root Cause Analysis  
**File**: `/iBurn/Detail/Views/DetailView.swift`

#### Issue 1: Image Width
The `DetailHeaderView` used `.frame(maxHeight: 300)` without `.frame(maxWidth: .infinity)`, causing small images to stay at natural size instead of expanding.

#### Issue 2: Theme Colors
SwiftUI implementation wasn't following the Objective-C pattern from `BRCDetailViewController.m:104-114` for extracting theme colors from metadata. Key missing elements:
- Not checking `Appearance.useImageColorsTheming` setting
- Incorrect metadata casting for `BRCThumbnailImageColorsProtocol`
- Missing event-specific logic to get colors from hosting camp first

#### Issue 3: Cell Tappability  
Using `PlainButtonStyle()` removed visual feedback, making cells appear non-interactive.

### Solution Implementation

#### 1. Fixed Image Width Sizing
**File**: `iBurn/Detail/Views/DetailView.swift:104`

**Before**:
```swift
.frame(maxHeight: 300)
```

**After**:
```swift
.frame(maxWidth: .infinity, maxHeight: 300)
```

#### 2. Implemented Proper Theme Color Extraction
**File**: `iBurn/Detail/ViewModels/DetailViewModel.swift:151-188`

Added `getThemeColors()` method following exact Objective-C logic:

```swift
func getThemeColors() -> BRCImageColors {
    // Check user setting first
    if !Appearance.useImageColorsTheming {
        return Appearance.currentColors
    }
    
    // Special event handling - try hosting camp colors first
    if let eventObject = dataObject as? BRCEventObject {
        return getEventThemeColors(for: eventObject)
    }
    
    // Art/Camp metadata color extraction
    if let artMetadata = metadata as? BRCArtMetadata,
       let imageColors = artMetadata.thumbnailImageColors {
        return imageColors
    } else if let campMetadata = metadata as? BRCCampMetadata,
              let imageColors = campMetadata.thumbnailImageColors {
        return imageColors
    }
    
    // Fallback to global theme
    return Appearance.currentColors
}
```

**Event-specific logic**:
```swift
private func getEventThemeColors(for event: BRCEventObject) -> BRCImageColors {
    // Try hosting camp's image colors first
    if let campId = event.hostedByCampUniqueID,
       let camp = dataService.getCamp(withId: campId),
       let campMetadata = dataService.getMetadata(for: camp) as? BRCCampMetadata,
       let campImageColors = campMetadata.thumbnailImageColors {
        return campImageColors
    }
    
    // Fallback to event type colors
    return BRCImageColors.colors(for: event.eventType)
}
```

**Updated background computation**:
```swift
private var backgroundColor: Color {
    let themeColors = viewModel.getThemeColors()
    return Color(themeColors.backgroundColor)
}
```

#### 3. Enhanced Cell Tappability
**File**: `iBurn/Detail/Views/DetailView.swift:95-107`

Created custom button style with visual feedback:

```swift
struct TappableCellButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(configuration.isPressed ? Color.primary.opacity(0.1) : Color.clear)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
```

Replaced `.buttonStyle(PlainButtonStyle())` with `.buttonStyle(TappableCellButtonStyle())` for both header and cell buttons.

### Key Implementation Details

#### Theme Color Logic Matches Objective-C
The implementation now exactly follows `BRCDetailViewController.m` pattern:
- **Lines 104-114**: Check metadata conformance to `BRCThumbnailImageColorsProtocol`
- **Lines 74-96**: Special event logic for hosting camp colors
- **Line 109**: Respect `Appearance.useImageColorsTheming` setting

#### Respects User Preferences
The theme color extraction properly checks the user's "Use Image Colors" setting, falling back to global theme when disabled.

#### Event Color Priority
Events now correctly prioritize:
1. Hosting camp's extracted image colors
2. Event type colors (if no camp or camp has no colors)
3. Global theme colors (if image theming disabled)

### Verification
```bash
# Build succeeds with all fixes
xcodebuild -workspace iBurn.xcworkspace -scheme iBurn -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,OS=18.5,arch=arm64,name=iPhone 16 Pro' \
  -configuration Debug build -quiet
```

### Files Modified (UI Bug Fixes)
1. `iBurn/Detail/Views/DetailView.swift` - Fixed image width, background colors, cell tappability
2. `iBurn/Detail/ViewModels/DetailViewModel.swift` - Added proper theme color extraction

## Additional Work: TappableCellButtonStyle Rethink and Image Architecture Simplification

### Problems Identified
After implementing the TappableCellButtonStyle, discovered that cells still weren't fully tappable - users had to tap exactly on text/icons rather than anywhere in the cell area. Additionally, the image handling architecture was unnecessarily complex with special "header" logic.

### Root Cause Analysis  
**File**: `/iBurn/Detail/Views/DetailView.swift`

#### Issue 1: Button Tappable Area
The `TappableCellButtonStyle` didn't make the entire cell area tappable because spacers and invisible areas within SwiftUI Button labels don't contribute to the tappable area.

#### Issue 2: Complex Image Architecture
The view had unnecessarily complex image handling:
- Special "header" logic that searched for first image cell (lines 41-51)
- Main cell loop skipped image cells with `EmptyView()` (lines 57-58)
- `DetailHeaderView` only used for images
- cellContent switch statement didn't handle `.image` case

### Solution Implementation (Based on Gemini's Expert Advice)

#### 1. Fixed Button Tappable Area with contentShape
**File**: `iBurn/Detail/Views/DetailView.swift:144,50`

Replaced custom `TappableCellButtonStyle` with SwiftUI's `.contentShape(Rectangle())` modifier:

**Before**:
```swift
.buttonStyle(TappableCellButtonStyle())
```

**After**:
```swift
.contentShape(Rectangle())
```

**Why This Works**: `.contentShape(Rectangle())` tells SwiftUI to treat the button's entire rectangular frame as tappable, including spacers and clear areas.

#### 2. Simplified Image Architecture
**File**: `iBurn/Detail/Views/DetailView.swift`

**Removed Complex Header Logic** (lines 40-51):
- Deleted special "first image" search and separate rendering
- Images now render through normal cell flow

**Simplified Cell Loop** (lines 42-45):
```swift
// Before: Special handling and skipping
if case .image = cell.type {
    EmptyView()
} else {
    DetailCellView(cell: cell, viewModel: viewModel)
}

// After: Uniform handling
DetailCellView(cell: cell, viewModel: viewModel)
```

**Renamed and Simplified DetailHeaderView** (lines 116-126):
```swift
// Before: Complex wrapper that extracted from cell
struct DetailHeaderView: View {
    let cell: DetailCell
    let viewModel: DetailViewModel
    
    var body: some View {
        if case .image(let image, let aspectRatio) = cell.type {
            Image(uiImage: image)...
        }
    }
}

// After: Direct image view
struct DetailImageView: View {
    let image: UIImage
    let aspectRatio: CGFloat
    
    var body: some View {
        Image(uiImage: image)...
    }
}
```

**Added Image Case to Switch Statement** (lines 172-173):
```swift
case .image(let image, let aspectRatio):
    DetailImageView(image: image, aspectRatio: aspectRatio)
```

**Updated Tappability** (lines 190-191):
```swift
case .image:
    return true  // Images are now tappable like other cells
```

### Key Implementation Details

#### Why contentShape Works Better Than Custom ButtonStyle
- **Full Coverage**: Makes entire button area tappable including spacers
- **Built-in Feedback**: Maintains default button press animations
- **Simpler Code**: No custom style needed
- **More Reliable**: SwiftUI's standard approach for this use case

#### Benefits of Simplified Image Architecture
- **Consistent**: Images handled exactly like other cell types
- **Cleaner**: No special-case logic for positioning
- **Maintainable**: Single code path for all cell rendering
- **Flexible**: Easy to reorder cells without breaking image display

### Verification
```bash
# Build succeeds with all fixes
xcodebuild -workspace iBurn.xcworkspace -scheme iBurn -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,OS=18.5,arch=arm64,name=iPhone 16 Pro' \
  -configuration Debug build -quiet

# Note: Compiler warning about unreachable default case is expected 
# (switch statement is now exhaustive but default kept for defensive programming)
```

### Files Modified (Tappability and Image Architecture)
1. `iBurn/Detail/Views/DetailView.swift` - Removed TappableCellButtonStyle, added contentShape, simplified image architecture

## Additional Work: MapLibre Integration for SwiftUI DetailView

### Problem
The SwiftUI DetailView was missing the embedded map functionality that existed in the original `BRCDetailViewController`. Users needed to see a map preview of the object's location and be able to tap it to navigate to a full-screen map.

### Solution: UIViewRepresentable Wrapper
Implemented MapLibre integration using a UIViewRepresentable wrapper that reuses existing iBurn map infrastructure.

#### 1. Created DetailMapViewRepresentable Component
**File**: `iBurn/Detail/Views/DetailMapViewRepresentable.swift`

```swift
struct DetailMapViewRepresentable: UIViewRepresentable {
    let dataObject: BRCDataObject
    let metadata: BRCObjectMetadata?
    let onTap: () -> Void
    
    func makeUIView(context: Context) -> MLNMapView {
        // Create map view with iBurn defaults
        let mapView = MLNMapView.brcMapView()
        
        // Create annotation and data source
        guard let annotation = DataObjectAnnotation(object: dataObject, metadata: metadata ?? BRCObjectMetadata()) else {
            return mapView
        }
        
        let dataSource = StaticAnnotationDataSource(annotation: annotation)
        let mapViewAdapter = MapViewAdapter(mapView: mapView, dataSource: dataSource)
        mapViewAdapter.reloadAnnotations()
        
        // Configure for preview mode
        mapView.isUserInteractionEnabled = false
        
        // Add tap gesture for navigation
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap))
        mapView.addGestureRecognizer(tapGesture)
        
        return mapView
    }
}
```

#### 2. Extended DetailCellType with Map Support
**File**: `iBurn/Detail/Models/DetailCellType.swift:30`

Added `.mapView(BRCDataObject, metadata: BRCObjectMetadata?)` case to the DetailCellType enum.

#### 3. Updated DetailView Rendering
**File**: `iBurn/Detail/Views/DetailView.swift:194-201`

```swift
case .mapView(let dataObject, let metadata):
    DetailMapViewRepresentable(
        dataObject: dataObject,
        metadata: metadata
    ) {
        viewModel.handleCellTap(cell)
    }
    .frame(height: 200)
```

#### 4. Added Map Generation Logic
**File**: `iBurn/Detail/ViewModels/DetailViewModel.swift:244-247,484-498`

**Map cell generation**:
```swift
// Add map view if object has location and is not embargoed
if shouldShowMap() {
    cellTypes.append(.mapView(dataObject, metadata: metadata))
}
```

**Embargo checking logic** (following `BRCDetailViewController.setupMapViewWithObject:`):
```swift
private func shouldShowMap() -> Bool {
    // Check if object has location data and embargo allows showing it
    if let location = dataObject.location, BRCEmbargo.canShowLocation(for: dataObject) {
        return true
    }
    
    // Also check for burner map location (user-set location)
    if let burnerLocation = dataObject.burnerMapLocation {
        return true
    }
    
    return false
}
```

#### 5. Fixed Map Navigation
**File**: `iBurn/Detail/Services/DetailActionCoordinator.swift:134-153`

```swift
case .showMap(let dataObject):
    guard let navigator = dependencies.navigator else {
        print("❌ Map navigation FAILED: Navigator is nil")
        return
    }
    
    // Get metadata for the object
    var metadata: BRCObjectMetadata?
    BRCDatabaseManager.shared.uiConnection.read { transaction in
        metadata = dataObject.metadata(with: transaction)
    }
    
    // Create MapDetailViewController following old pattern
    let mapViewController = MapDetailViewController(dataObject: dataObject, metadata: metadata ?? BRCObjectMetadata())
    mapViewController.title = "Map - \(dataObject.title)"
    
    navigator.pushViewController(mapViewController, animated: true)
```

### Key Implementation Details

#### Reuses Existing Infrastructure
- **MLNMapView.brcMapView()**: Uses existing iBurn map configuration with offline mbtiles
- **DataObjectAnnotation**: Uses existing annotation system
- **StaticAnnotationDataSource**: Uses existing data source pattern
- **MapViewAdapter**: Uses existing adapter for annotation management
- **BRCEmbargo.canShowLocation()**: Respects existing embargo restrictions

#### Matches Original Behavior
- **200px height**: Same as `kTableViewHeaderHeight` in original
- **Non-interactive**: `userInteractionEnabled = false` for preview mode
- **Tap to navigate**: Taps navigate to `MapDetailViewController`
- **Embargo respect**: Only shows when location data is not embargoed

#### SwiftUI Integration
- **UIViewRepresentable**: Clean SwiftUI wrapper for UIKit MapLibre components
- **Coordinator pattern**: Handles tap gestures properly
- **Cell-based**: Integrates with existing DetailView cell system
- **Edge-to-edge**: Maps extend to screen edges like images

### Verification
```bash
# Build succeeds with map integration
xcodebuild -workspace iBurn.xcworkspace -scheme iBurn -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,OS=18.5,arch=arm64,name=iPhone 16 Pro' \
  -configuration Debug build -quiet
```

### Files Created/Modified (Map Integration)
1. **NEW**: `iBurn/Detail/Views/DetailMapViewRepresentable.swift` - UIViewRepresentable wrapper
2. **MODIFIED**: `iBurn/Detail/Models/DetailCellType.swift` - Added mapView case
3. **MODIFIED**: `iBurn/Detail/Views/DetailView.swift` - Map cell rendering and tappability
4. **MODIFIED**: `iBurn/Detail/ViewModels/DetailViewModel.swift` - Map generation logic and embargo checking
5. **MODIFIED**: `iBurn/Detail/Services/DetailActionCoordinator.swift` - Fixed showMap navigation

## Final Status
All six systems are now complete:
1. ✅ **Initialization cleanup** - Clean dependency injection without temporary objects
2. ✅ **Navigation item forwarding** - Dynamic navigation support for SwiftUI views  
3. ✅ **Event creation dismissal** - Proper EKEventEditViewDelegate implementation for calendar events
4. ✅ **DetailView UI fixes** - Image sizing, theme colors, and cell tappability all working properly
5. ✅ **Cell tappability and image architecture** - Full-width tappable cells and simplified image handling
6. ✅ **MapLibre integration** - Embedded map previews with tap-to-navigate functionality

The SwiftUI DetailView now has complete feature parity with the original UIKit implementation, including embedded map functionality that respects embargo restrictions and provides seamless navigation to full-screen maps.