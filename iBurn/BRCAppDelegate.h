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
#import "BRCEventsTableViewController.h"

@class FavoritesViewController;
@class MainMapViewController;
@class EventListViewController;

NS_ASSUME_NONNULL_BEGIN
@interface BRCAppDelegate : UIResponder <UIApplicationDelegate, UITabBarControllerDelegate, CLLocationManagerDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (nonatomic, strong) UITabBarController *tabBarController;

@property (nonatomic, strong) CLLocationManager *locationManager;

@property (nonatomic, strong) MainMapViewController *mapViewController;
@property (nonatomic, strong) FavoritesViewController *favoritesViewController;
@property (nonatomic, strong) EventListViewController *eventsViewController;

/** Don't use this unless you really have to... */
@property (nonatomic, class, readonly) BRCAppDelegate *shared;

+ (void) openURL:(NSURL*)url fromViewController:(UIViewController*)viewController;

#pragma mark Permissions

/** Asks for remotification permission */
+ (void) registerForRemoteNotifications;
/** Asks for location and starts updating */
- (void) requestLocationPermission;

@end
NS_ASSUME_NONNULL_END
