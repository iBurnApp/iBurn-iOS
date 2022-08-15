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

@class FavoritesViewController;
@class MainMapViewController;
@class EventListViewController;
@class TabController;

NS_ASSUME_NONNULL_BEGIN
@interface BRCAppDelegate : UIResponder <UIApplicationDelegate, UITabBarControllerDelegate, CLLocationManagerDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (nonatomic, strong) TabController *tabBarController;

@property (nonatomic, strong) CLLocationManager *locationManager;

@property (nonatomic, strong) MainMapViewController *mapViewController;
@property (nonatomic, strong) FavoritesViewController *favoritesViewController;
@property (nonatomic, strong) EventListViewController *eventsViewController;

/** Don't use this unless you really have to... */
@property (nonatomic, class, readonly) BRCAppDelegate *shared;

#pragma mark Permissions

/** Asks for remotification permission */
+ (void) registerForRemoteNotifications;
/** Asks for location and starts updating */
- (void) requestLocationPermission;

@end
NS_ASSUME_NONNULL_END
