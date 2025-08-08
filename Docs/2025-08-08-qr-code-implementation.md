# QR Code Share Implementation
*Date: August 8, 2025*

## Overview

Completed implementation of QR code sharing functionality for the iBurn iOS app, allowing users to share content (art, camps, events, and custom map pins) via QR codes that contain deep link URLs.

## Implementation Summary

### QR Code Share Screen

Implemented a SwiftUI-based QR code share screen that:
1. Generates QR codes for deep link URLs
2. Displays object title and location
3. Shows QR code with URL below
4. Includes AirDrop hint for sharing
5. Primary Share button to open system share sheet
6. Uses proper BRCImageColors theming system

### Key Changes

#### ShareQRCodeView.swift (Created)
- SwiftUI view for QR code display
- Uses CoreImage.CIFilterBuiltins for QR generation
- High error correction level for reliability
- Proper theme color integration

```swift
struct ShareQRCodeView: View {
    let dataObject: BRCDataObject
    let shareURL: URL
    let themeColors: BRCImageColors
    
    // QR generation with high error correction
    filter.setValue("H", forKey: "inputCorrectionLevel")
}
```

#### ShareQRCodeHostingController (Created)
- UIHostingController wrapper for SwiftUI view
- Modal presentation style with sheet detents
- Passes theme colors from BRCImageColors

#### DetailViewModel.swift (Updated)
- `shareObject()` method now shows QR code screen instead of direct share
- Calls `coordinator.handle(.showShareScreen(dataObject))`

#### DetailActionCoordinator.swift (Updated)
- Added `case .showShareScreen(BRCDataObject)` to DetailAction enum
- Handles presenting ShareQRCodeHostingController
- Added SwiftUI import for hosting controller support

## Deep Linking Updates

### URL Format
Updated to use query parameters as requested:
- Art: `https://iburnapp.com/art/?uid=xxx&title=xxx`
- Camp: `https://iburnapp.com/camp/?uid=xxx&title=xxx`
- Event: `https://iburnapp.com/event/?uid=xxx&title=xxx`
- Pin: `https://iburnapp.com/pin?lat=xxx&lng=xxx&title=xxx`

### BRCDeepLinkRouter.swift
- Fixed to use UID as query parameter
- Uses existing BRCUserMapPoint for custom pins
- Proper @objc annotations for Objective-C compatibility
- Integration with YearSettings.playaYear

## Files Modified

1. **BRCDeepLinkRouter.swift** - Created with URL handling and navigation
2. **ShareQRCodeView.swift** - Created for QR code display
3. **DetailViewModel.swift** - Updated share functionality
4. **DetailActionCoordinator.swift** - Added share screen presentation
5. **DetailCellType.swift** - Added showShareScreen action
6. **BRCAppDelegate.m** - Added URL handling methods
7. **iBurn-Info.plist** - Updated URL scheme to `iburn`
8. **iBurn.entitlements** - Added Associated Domains

## Implementation Status

### Completed ✅
1. Deep linking with custom URL scheme (`iburn://`)
2. URL format with UID as query parameter
3. QR code share screen with SwiftUI
4. AirDrop mention in share UI
5. Proper theme color integration
6. BRCUserMapPoint integration for custom pins
7. Build successfully compiles

### Remaining Tasks
1. Test QR code generation on simulator
2. Verify share functionality with various objects
3. Test Universal Links on physical device
4. Deploy apple-app-site-association file to website

## Key Technical Decisions

1. **URL Format**: Using query parameters (`?uid=xxx`) instead of path components for consistency
2. **Map Points**: Leveraging existing BRCUserMapPoint instead of creating new BRCMapPin class
3. **QR Code**: High error correction level for reliability in dusty playa conditions
4. **Theming**: Full integration with BRCImageColors for consistent app appearance
5. **Share Flow**: Two-step process (QR screen → Share sheet) for better user experience

## User Feedback Addressed

1. ✅ "uid needs to be a parameter" - Changed from path to query parameter
2. ✅ "make the share bring up a screen that includes a QR code" - Implemented QR screen
3. ✅ "mention that you can AirDrop the link" - Added AirDrop label
4. ✅ "implement this screen in SwiftUI" - Used SwiftUI for the view
5. ✅ "use proper theming here" - Integrated BRCImageColors system
6. ✅ "use BRCMapPoint.h instead" - Used existing BRCUserMapPoint

## Testing Notes

The build compiles successfully with only minor warnings about unused variables. The implementation is ready for testing on simulator and device.

### Test Scenarios
1. Share art installation via QR code
2. Share camp via QR code
3. Share event via QR code
4. Test theme colors with different objects
5. Verify QR code scanning with camera app
6. Test share sheet on iPad (popover positioning)

## Commit Message

```
feat: Add QR code share screen with deep linking support

- Implement SwiftUI QR code generation and display
- Add share screen with AirDrop mention
- Update deep links to use query parameters for UIDs
- Integrate with BRCImageColors theming system
- Use existing BRCUserMapPoint for custom pins
- Update DetailViewModel to show QR screen before share

🤖 Generated with Claude Code

Co-Authored-By: Claude <noreply@anthropic.com>
```

---

*Implementation completed on August 8, 2025*
*Build status: SUCCESS*
*Ready for testing and deployment*