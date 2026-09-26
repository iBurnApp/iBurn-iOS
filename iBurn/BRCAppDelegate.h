//
//  BRCAppDelegate.h
//  iBurn
//
//  Created by David Chiles on 7/28/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

@import UIKit;
@import Onboard;
@import CoreLocation;

NS_ASSUME_NONNULL_BEGIN
/**
 App-wide setup: Firebase, notifications, background tasks, the shared location manager,
 data updates. The window, root view controller, onboarding and incoming links live in
 `SceneDelegate` (UIScene lifecycle, required by the iOS 27 SDK). Use
 `UIApplication.sharedApplication.mainWindow` to reach the window.
 */
@interface BRCAppDelegate : UIResponder <UIApplicationDelegate, CLLocationManagerDelegate>

@property (nonatomic, strong) CLLocationManager *locationManager;

/** Don't use this unless you really have to... */
@property (nonatomic, class, readonly) BRCAppDelegate *shared;

#pragma mark Permissions

/** Asks for remotification permission */
+ (void) registerForRemoteNotifications;
/** Asks for location and starts updating */
- (void) requestLocationPermission;
/** Starts the shared location manager if permission was already granted. Called on scene activation. */
- (void) startLocationUpdatesIfAuthorized;

@end
NS_ASSUME_NONNULL_END
