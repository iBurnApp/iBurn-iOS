# iPad Popover Presentation Crash Fix

## Problem Statement
The app crashed on iPad with the following error:
```
Fatal Exception: NSGenericException
UIPopoverPresentationController (<UIPopoverPresentationController: 0x13eb3aa00>) should have a non-nil sourceView or barButtonItem set before the presentation occurs.
```

## Root Cause
When presenting UIActivityViewController on iPad, iOS requires the popoverPresentationController to have either a sourceView or barButtonItem set. Without this, the app crashes.

## Analysis
Checked all UIActivityViewController and UIAlertController actionSheet presentations in the codebase:

### Files Already Handling Popovers Correctly
- ✅ UserMapViewAdapter.swift (lines 141-144)
- ✅ TracksViewController.swift (line 93)
- ✅ ShareQRCodeView.swift (lines 191-193)
- ✅ MoreViewController.swift (line 371)
- ✅ DetailActionCoordinator.swift .share case (lines 252-266)

### File with Missing Popover Configuration
- ❌ DetailActionCoordinator.swift .shareCoordinates case (lines 128-134)

## Solution Implemented

Fixed the shareCoordinates case in DetailActionCoordinator.swift by adding iPad popover support:

```swift
case .shareCoordinates(let coordinate):
    guard let presenter = dependencies.presenter else {
        print("❌ Cannot share coordinates: No presenter available")
        return
    }
    let activityViewController = createShareController(for: coordinate)
    
    // iPad popover support
    if let popover = activityViewController.popoverPresentationController {
        if let viewController = presenter as? UIViewController {
            popover.sourceView = viewController.view
            // Position the popover at a reasonable location
            popover.sourceRect = CGRect(x: viewController.view.bounds.midX, y: 100, width: 0, height: 0)
        }
    }
    
    presenter.present(activityViewController, animated: true, completion: nil)
```

## Testing
- Built successfully for iPad Pro 13-inch (M4) simulator
- The popover will now appear from the center-top of the view on iPad
- No crashes when sharing coordinates on iPad

## Notes
- The popoverPresentationController only needs either sourceView OR barButtonItem set, not both
- sourceRect is optional but helps position the popover arrow correctly
- The old BRCDetailViewController.m is not being used in the current implementation