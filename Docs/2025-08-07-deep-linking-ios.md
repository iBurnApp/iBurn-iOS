# iOS Deep Linking Implementation Guide
*Date: August 7, 2025*

## Overview

This guide provides detailed implementation instructions for adding deep linking support to the iBurn iOS app. The implementation will support both custom URL schemes (`iburn://`) and Universal Links (`https://iburnapp.com`).

## Current State Analysis

### Existing Infrastructure
- **Legacy URL Scheme**: `haf0ca0d3f6e80591495cf24f7f513abdf` in Info.plist
- **No URL handling** in AppDelegate
- **No SceneDelegate** (app uses legacy AppDelegate pattern)
- **Navigation**: `TabController` (UITabBarController) with 5 tabs
- **Detail Views**: `DetailViewControllerFactory` supports both UIKit and SwiftUI

### Data Model
- **Base Class**: `BRCDataObject` with `uniqueId` property
- **Object Types**: 
  - `BRCArtObject` - Art installations
  - `BRCCampObject` - Theme camps
  - `BRCEventObject` - Events
- **Database**: YapDatabase with `BRCDatabaseManager`
- **Identifiers**: `uid` property contains Salesforce-style IDs

## Implementation Steps

### Step 1: Update URL Schemes

#### 1.1 Modify Info.plist

```xml
<!-- iBurn-Info.plist -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>com.iburnapp.iburn</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>iburn</string>
        </array>
    </dict>
</array>
```

#### 1.2 Add Associated Domains Entitlement

Create or update `iBurn.entitlements`:

```xml
<key>com.apple.developer.associated-domains</key>
<array>
    <string>applinks:iburnapp.com</string>
    <string>applinks:www.iburnapp.com</string>
</array>
```

### Step 2: Create Deep Link Router

#### 2.1 BRCDeepLinkRouter.swift

```swift
import UIKit

enum DeepLinkObjectType: String {
    case art = "art"
    case camp = "camp"
    case event = "event"
    case pin = "pin"
}

class BRCDeepLinkRouter: NSObject {
    
    static let shared = BRCDeepLinkRouter()
    
    private weak var tabController: TabController?
    
    func configure(with tabController: TabController) {
        self.tabController = tabController
    }
    
    // MARK: - URL Handling
    
    func canHandle(_ url: URL) -> Bool {
        if url.scheme == "iburn" {
            return true
        }
        if url.host == "iburnapp.com" || url.host == "www.iburnapp.com" {
            return true
        }
        return false
    }
    
    func handle(_ url: URL) -> Bool {
        guard canHandle(url) else { return false }
        
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        guard let firstComponent = pathComponents.first else { return false }
        
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let metadata = Dictionary(uniqueKeysWithValues: queryItems.compactMap { item in
            guard let value = item.value else { return nil }
            return (item.name, value)
        })
        
        switch firstComponent {
        case "art", "camp", "event":
            guard pathComponents.count >= 2 else { return false }
            let uid = pathComponents[1]
            return navigateToObject(uid: uid, type: firstComponent, metadata: metadata)
            
        case "pin":
            return createMapPin(from: metadata)
            
        default:
            return false
        }
    }
    
    // MARK: - Navigation
    
    private func navigateToObject(uid: String, type: String, metadata: [String: String]) -> Bool {
        guard let tabController = tabController else { return false }
        
        // Find object in database
        let connection = BRCDatabaseManager.shared.uiConnection
        var object: BRCDataObject?
        
        connection?.read { transaction in
            switch type {
            case "art":
                object = transaction.object(forKey: uid, inCollection: BRCArtObject.collection) as? BRCArtObject
            case "camp":
                object = transaction.object(forKey: uid, inCollection: BRCCampObject.collection) as? BRCCampObject
            case "event":
                object = transaction.object(forKey: uid, inCollection: BRCEventObject.collection) as? BRCEventObject
            default:
                break
            }
        }
        
        guard let dataObject = object else {
            // Object not found - show error or search
            showObjectNotFound(uid: uid, type: type, metadata: metadata)
            return false
        }
        
        // Navigate to object
        DispatchQueue.main.async {
            // Switch to appropriate tab
            tabController.selectedIndex = 0 // Map tab
            
            // Push detail view
            let detailVC = DetailViewControllerFactory.viewController(for: dataObject)
            if let navController = tabController.selectedViewController as? UINavigationController {
                navController.pushViewController(detailVC, animated: true)
            }
        }
        
        return true
    }
    
    private func createMapPin(from metadata: [String: String]) -> Bool {
        guard let latString = metadata["lat"],
              let lngString = metadata["lng"],
              let latitude = Double(latString),
              let longitude = Double(lngString) else {
            return false
        }
        
        let title = metadata["title"] ?? "Custom Pin"
        let description = metadata["desc"]
        let address = metadata["addr"]
        let color = metadata["color"] ?? "red"
        
        // Create and save custom pin
        let pin = BRCMapPin()
        pin.uid = UUID().uuidString
        pin.title = title
        pin.subtitle = description
        pin.playaAddress = address
        pin.latitude = latitude
        pin.longitude = longitude
        pin.color = color
        pin.createdDate = Date()
        
        // Save to database
        BRCDatabaseManager.shared.readWriteConnection?.asyncReadWrite { transaction in
            transaction.setObject(pin, forKey: pin.uid, inCollection: BRCMapPin.collection)
        }
        
        // Navigate to map and show pin
        DispatchQueue.main.async {
            guard let tabController = self.tabController else { return }
            
            // Switch to map tab
            tabController.selectedIndex = 0
            
            // Center map on pin
            if let navController = tabController.selectedViewController as? UINavigationController,
               let mapVC = navController.viewControllers.first as? MainMapViewController {
                mapVC.centerOnCoordinate(CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
                mapVC.selectAnnotation(for: pin)
            }
        }
        
        return true
    }
    
    private func showObjectNotFound(uid: String, type: String, metadata: [String: String]) {
        let title = metadata["title"] ?? "Content"
        let message = "\(title) could not be found. It may not be available yet or may have been removed."
        
        let alert = UIAlertController(title: "Not Found", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        DispatchQueue.main.async {
            self.tabController?.present(alert, animated: true)
        }
    }
}
```

#### 2.2 BRCMapPin.swift (New Model)

```swift
import Foundation
import CoreLocation

@objc class BRCMapPin: BRCDataObject {
    
    @objc dynamic var color: String = "red"
    @objc dynamic var createdDate: Date = Date()
    @objc dynamic var notes: String?
    
    override class var collection: String {
        return "BRCMapPinCollection"
    }
    
    // MARK: - YapDatabase
    
    override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        coder.encode(color, forKey: "color")
        coder.encode(createdDate, forKey: "createdDate")
        coder.encode(notes, forKey: "notes")
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        color = coder.decodeObject(forKey: "color") as? String ?? "red"
        createdDate = coder.decodeObject(forKey: "createdDate") as? Date ?? Date()
        notes = coder.decodeObject(forKey: "notes") as? String
    }
    
    override init() {
        super.init()
    }
}
```

### Step 3: Update AppDelegate

#### 3.1 Add URL Handling Methods

```objc
// BRCAppDelegate.m

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options {
    return [[BRCDeepLinkRouter shared] handleURL:url];
}

- (BOOL)application:(UIApplication *)application continueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void (^)(NSArray<id<UIUserActivityRestoring>> * _Nullable))restorationHandler {
    if ([userActivity.activityType isEqualToString:NSUserActivityTypeBrowsingWeb]) {
        NSURL *url = userActivity.webpageURL;
        if (url) {
            return [[BRCDeepLinkRouter shared] handleURL:url];
        }
    }
    return NO;
}
```

#### 3.2 Configure Router on Launch

```objc
// In application:didFinishLaunchingWithOptions:

// After TabController is created
[[BRCDeepLinkRouter shared] configureWithTabController:self.tabController];

// Check if launched from URL
NSURL *launchURL = [launchOptions objectForKey:UIApplicationLaunchOptionsURLKey];
if (launchURL) {
    // Delay to ensure UI is ready
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[BRCDeepLinkRouter shared] handleURL:launchURL];
    });
}
```

### Step 4: Add Share Functionality

#### 4.1 Share URL Generator

```swift
// BRCShareURLGenerator.swift

extension BRCDataObject {
    
    func generateShareURL() -> URL? {
        var components = URLComponents(string: "https://iburnapp.com")!
        
        // Add path based on object type
        if self is BRCArtObject {
            components.path = "/art/\(uid)"
        } else if self is BRCCampObject {
            components.path = "/camp/\(uid)"
        } else if self is BRCEventObject {
            components.path = "/event/\(uid)"
        } else {
            return nil
        }
        
        // Add query parameters
        var queryItems: [URLQueryItem] = []
        
        // Universal parameters
        queryItems.append(URLQueryItem(name: "title", value: title))
        
        if let location = location {
            queryItems.append(URLQueryItem(name: "lat", value: String(format: "%.6f", location.coordinate.latitude)))
            queryItems.append(URLQueryItem(name: "lng", value: String(format: "%.6f", location.coordinate.longitude)))
        }
        
        if let playaAddress = playaAddress, !playaAddress.isEmpty {
            queryItems.append(URLQueryItem(name: "addr", value: playaAddress))
        }
        
        if let snippet = snippet, !snippet.isEmpty {
            let truncated = String(snippet.prefix(100))
            queryItems.append(URLQueryItem(name: "desc", value: truncated))
        }
        
        // Event-specific parameters
        if let event = self as? BRCEventObject {
            if let startDate = event.startDate {
                queryItems.append(URLQueryItem(name: "start", value: ISO8601DateFormatter().string(from: startDate)))
            }
            if let endDate = event.endDate {
                queryItems.append(URLQueryItem(name: "end", value: ISO8601DateFormatter().string(from: endDate)))
            }
            
            // Add host information
            if let campHost = event.hostedByCamp {
                queryItems.append(URLQueryItem(name: "host", value: campHost.title))
                queryItems.append(URLQueryItem(name: "host_id", value: campHost.uid))
                queryItems.append(URLQueryItem(name: "host_type", value: "camp"))
            } else if let artHost = event.hostedByArt {
                queryItems.append(URLQueryItem(name: "host", value: artHost.title))
                queryItems.append(URLQueryItem(name: "host_id", value: artHost.uid))
                queryItems.append(URLQueryItem(name: "host_type", value: "art"))
            }
            
            if event.allDay {
                queryItems.append(URLQueryItem(name: "all_day", value: "true"))
            }
        }
        
        // Add year
        let yearSettings = YearSettings.current
        queryItems.append(URLQueryItem(name: "year", value: String(yearSettings.year)))
        
        components.queryItems = queryItems
        
        return components.url
    }
}
```

#### 4.2 Add Share Button to Detail Views

```swift
// In DetailViewController or relevant view controllers

private func shareButtonTapped() {
    guard let shareURL = dataObject.generateShareURL() else { return }
    
    let activityItems: [Any] = [
        "\(dataObject.title) at Burning Man",
        shareURL
    ]
    
    let activityController = UIActivityViewController(
        activityItems: activityItems,
        applicationActivities: nil
    )
    
    // iPad support
    if let popover = activityController.popoverPresentationController {
        popover.barButtonItem = shareBarButtonItem
    }
    
    present(activityController, animated: true)
}
```

### Step 5: apple-app-site-association File

Create this file for the website repository:

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "TEAMID.com.iburnapp.iburn",
        "paths": [
          "/art/*",
          "/camp/*",
          "/event/*",
          "/pin"
        ]
      }
    ]
  }
}
```

**Important**: Replace `TEAMID` with your actual Apple Developer Team ID.

### Step 6: Testing

#### 6.1 Test Custom URL Scheme

```bash
# Test in Simulator
xcrun simctl openurl booted "iburn://art/a2Id0000000cbObEAI"
xcrun simctl openurl booted "iburn://pin?lat=40.7868&lng=-119.2068&title=Test%20Pin"
```

#### 6.2 Test Universal Links

1. Deploy `apple-app-site-association` to website
2. Install app on device (not Simulator)
3. Test links in Notes app or Messages
4. Verify direct app opening

#### 6.3 Test Matrix

| Scenario | URL | Expected Result |
|----------|-----|-----------------|
| Art object | `iburn://art/[uid]` | Opens art detail |
| Camp object | `iburn://camp/[uid]` | Opens camp detail |
| Event object | `iburn://event/[uid]` | Opens event detail |
| Custom pin | `iburn://pin?lat=40.78&lng=-119.20&title=Test` | Creates pin on map |
| Missing object | `iburn://art/invalid` | Shows error alert |
| Web link | `https://iburnapp.com/art/[uid]` | Opens in app |

### Step 7: Database Migration

Add support for custom pins collection:

```objc
// BRCDatabaseManager.m

- (void)setupDatabaseViews {
    // ... existing views ...
    
    // Add map pins view
    YapDatabaseViewGrouping *pinsGrouping = [YapDatabaseViewGrouping withObjectBlock:^NSString *(YapDatabaseReadTransaction *transaction, NSString *collection, NSString *key, id object) {
        if ([object isKindOfClass:[BRCMapPin class]]) {
            return @"pins";
        }
        return nil;
    }];
    
    YapDatabaseViewSorting *pinsSorting = [YapDatabaseViewSorting withObjectBlock:^NSComparisonResult(YapDatabaseReadTransaction *transaction, NSString *group, NSString *collection1, NSString *key1, id object1, NSString *collection2, NSString *key2, id object2) {
        BRCMapPin *pin1 = (BRCMapPin *)object1;
        BRCMapPin *pin2 = (BRCMapPin *)object2;
        return [pin2.createdDate compare:pin1.createdDate]; // Newest first
    }];
    
    YapDatabaseView *pinsView = [[YapDatabaseView alloc] initWithGrouping:pinsGrouping sorting:pinsSorting];
    [database registerExtension:pinsView withName:@"mapPins"];
}
```

## Performance Considerations

1. **Database Queries**: Use existing YapDatabase connections and views
2. **URL Parsing**: Cache parsed results if processing multiple URLs
3. **Navigation**: Ensure UI updates happen on main thread
4. **Image Loading**: Lazy load images for shared content

## Security Considerations

1. **URL Validation**: Validate all URL parameters
2. **Coordinate Bounds**: Check coordinates are within Black Rock City
3. **String Sanitization**: Sanitize user-provided strings
4. **Database Safety**: Use transactions for all database operations

## Troubleshooting

### Common Issues

1. **Universal Links not working**
   - Verify Team ID in apple-app-site-association
   - Check entitlements are properly configured
   - Ensure website serves file over HTTPS
   - Test on real device, not Simulator

2. **Object not found**
   - Check database has been populated
   - Verify UID format matches expected pattern
   - Ensure correct collection is being queried

3. **Navigation fails**
   - Verify TabController is properly initialized
   - Check view controller hierarchy
   - Ensure navigation happens on main thread

## Future Enhancements

1. **Offline Caching**: Cache shared objects locally
2. **QR Codes**: Generate QR codes for easy sharing
3. **Share Extensions**: iOS Share Extension for system-wide sharing
4. **Spotlight Integration**: Index content for system search
5. **Handoff Support**: Continue browsing between devices

## Conclusion

This implementation provides comprehensive deep linking support for the iBurn iOS app, enabling users to share and access content through both custom URL schemes and Universal Links. The architecture is designed to be maintainable and extensible for future enhancements.

---

*Last Updated: August 7, 2025*
*Platform: iOS 13.0+*
*Swift Version: 5.0*