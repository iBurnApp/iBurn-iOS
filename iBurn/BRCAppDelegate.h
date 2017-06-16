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

@class BRCFavoritesViewController;
@class MapViewController;

@interface BRCAppDelegate : UIResponder <UIApplicationDelegate, UITabBarControllerDelegate, CLLocationManagerDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (nonatomic, strong) UITabBarController *tabBarController;

@property (nonatomic, strong) CLLocationManager *locationManager;

@property (nonatomic, strong) MapViewController *mapViewController;
@property (nonatomic, strong) BRCFavoritesViewController *favoritesViewController;
@property (nonatomic, strong) BRCFilteredTableViewController *artViewController;
@property (nonatomic, strong) BRCFilteredTableViewController *campsViewController;
@property (nonatomic, strong) BRCEventsTableViewController *eventsViewController;

/** Don't use this unless you really have to... */
+ (instancetype) sharedAppDelegate;

+ (void) openURL:(NSURL*)url fromViewController:(UIViewController*)viewController;

#pragma mark Permissions

/** Asks for remotification permission */
+ (void) registerForRemoteNotifications;
/** Asks for location and starts updating */
- (void) requestLocationPermission;

@end
