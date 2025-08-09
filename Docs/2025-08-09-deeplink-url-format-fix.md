# Deep Link URL Format Fix
*Date: August 9, 2025*

## Overview
Fixed deep link URL parsing issue where `iburn://` scheme URLs without path separators were not being handled correctly, causing deep links from the web to fail.

## Problem Statement
The iBurn deep linking feature was failing when URLs were generated from the web interface. Investigation revealed a URL format mismatch:

- **Web generated**: `iburn://art?uid=abc123` (no path separator)
- **iOS expected**: `iburn://art/?uid=abc123` (with path separator)

## Root Cause Analysis

### Web Implementation (JavaScript)
The `deeplink-handler.js` was generating URLs without path separators:
```javascript
buildDeepLinkUrl() {
    let deepLink = `iburn://`;
    deepLink += `${this.type}?uid=${this.uid}`; // Results in: iburn://art?uid=123
}
```

### iOS Implementation (Swift)
The `BRCDeepLinkRouter.swift` was only checking `url.pathComponents`:
```swift
let pathComponents = url.pathComponents.filter { $0 != "/" }
guard let firstComponent = pathComponents.first else { 
    return false // Would fail for iburn://art?uid=123 (no path)
}
```

For `iburn://art?uid=123`, the URL has no path components (only a host), causing the parsing to fail.

## Solution

### Approach
Modified the iOS deep link router to handle both URL formats by using appropriate URL components:
- For `iburn://` scheme URLs: Use `url.host` as the type component
- For `https://` URLs: Continue using `url.pathComponents`

### Implementation Details
Updated `BRCDeepLinkRouter.swift` line 43-95 to:

```swift
@objc func handleURL(_ url: URL) -> Bool {
    // Extract the type component based on URL scheme
    let typeComponent: String?
    
    if url.scheme == "iburn" {
        // For iburn:// URLs, the host IS the type (e.g., iburn://art?uid=123)
        typeComponent = url.host
    } else {
        // For https URLs, use path components (e.g., https://iburnapp.com/art/?uid=123)
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        typeComponent = pathComponents.first
    }
    
    guard let firstComponent = typeComponent else { 
        return false 
    }
    
    // Continue with existing logic...
}
```

## URL Format Support

### Now Supported Formats
All of the following URL formats now work correctly:

#### Custom Scheme (iburn://)
- ✅ `iburn://art?uid=a1XVI000008yf262AA` (web-generated format)
- ✅ `iburn://art/?uid=a1XVI000008yf262AA` (backward compatible)
- ✅ `iburn://camp?uid=a1XVI000008zNKs2AM`
- ✅ `iburn://event?uid=event123`
- ✅ `iburn://pin?lat=40.7868&lng=-119.2068&title=Test`

#### Universal Links (https://)
- ✅ `https://iburnapp.com/art/?uid=a1XVI000008yf262AA`
- ✅ `https://iburnapp.com/camp/?uid=a1XVI000008zNKs2AM`
- ✅ `https://iburnapp.com/event/?uid=event123`
- ✅ `https://iburnapp.com/pin?lat=40.7868&lng=-119.2068`

## Testing

### Test Commands
```bash
# Test web-generated format (no slash)
xcrun simctl openurl booted "iburn://art?uid=a2Id0000000cbObEAI&title=Test%20Art"

# Test backward compatible format (with slash)  
xcrun simctl openurl booted "iburn://art/?uid=a2Id0000000cbObEAI&title=Test%20Art"

# Test pin creation
xcrun simctl openurl booted "iburn://pin?lat=40.7868&lng=-119.2068&title=Test%20Pin"

# Test camp link
xcrun simctl openurl booted "iburn://camp?uid=a1XVI000008zNKs2AM"

# Test event link
xcrun simctl openurl booted "iburn://event?uid=event123&title=Sunrise%20Yoga"
```

### Expected Behavior
- All URLs should successfully launch the app
- Art/Camp/Event URLs should open the detail view for the specified object
- Pin URLs should create a new map pin and show confirmation
- Unknown UIDs should show "Not Found" alert

## Benefits

1. **Backward Compatibility**: Existing URLs with path separators continue to work
2. **Web Compatibility**: JavaScript-generated URLs now work without modification
3. **Clean Implementation**: Uses standard URL components (`host` and `pathComponents`)
4. **Future Proof**: Handles both custom scheme and universal link formats

## Files Modified

1. `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/BRCDeepLinkRouter.swift` - Updated URL parsing logic

## Related Documentation
- [2025-08-08-deeplink-implementation.md](2025-08-08-deeplink-implementation.md) - Original deep linking implementation
- [2025-08-07-deep-linking-ios.md](2025-08-07-deep-linking-ios.md) - iOS deep linking overview