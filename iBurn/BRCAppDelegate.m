//
//  BRCAppDelegate.m
//  iBurn
//
//  Created by David Chiles on 7/28/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCAppDelegate.h"
#import "BRCDatabaseManager.h"
#import "BRCDataImporter.h"
#import "BRCArtObject.h"
#import "BRCCampObject.h"
#import "BRCRecurringEventObject.h"
#import "BRCEventObject_Private.h"
#import "NSDateFormatter+iBurn.h"
#import "BRCSecrets.h"
#import "BRCEmbargo.h"
#import "NSUserDefaults+iBurn.h"
#import "BRCEventObject.h"
#import "BRCDetailViewController.h"
#import "CLLocationManager+iBurn.h"
#import "Appirater.h"
#import "TUSafariActivity.h"
#import <WebKit/WebKit.h>
@import TTTAttributedLabel;
#import "BRCAcknowledgementsViewController.h"
#import "BRCEmbargoPasscodeViewController.h"
#import "iBurn-Swift.h"
#import "NSBundle+iBurn.h"
#import "NSUserDefaults+iBurn.h"
#import "BRCBreadcrumbPoint.h"
#import "BRCDataImporter_Private.h"
@import PermissionScope;
#import "NSDate+iBurn.h"
@import AVFoundation;
@import CocoaLumberjack;
@import FirebaseCore;

static int ddLogLevel = DDLogLevelVerbose;

static NSString * const kBRCBackgroundFetchIdentifier = @"kBRCBackgroundFetchIdentifier";

@interface BRCAppDelegate() <UINavigationControllerDelegate>
@property (nonatomic, strong) CLCircularRegion *burningManRegion;
@property (nonatomic, strong, readonly) BRCDataImporter *dataImporter;
@property (nonatomic, strong, readonly) BRCMediaDownloader *audioDownloader;
@property (nonatomic, strong, readonly) BRCMediaDownloader *imageDownloader;

@end

@implementation BRCAppDelegate
@synthesize dataImporter = _dataImporter;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [FIRApp configure];
    [Appearance setGlobalAppearance];
    
#if DEBUG
    [DDLog addLogger:[DDTTYLogger sharedInstance]];

    DDFileLogger *fileLogger = [[DDFileLogger alloc] init];
    fileLogger.doNotReuseLogFiles = YES;
    [DDLog addLogger:fileLogger withLevel:DDLogLevelAll];
#endif
    
    [BRCDataImporter copyBundledTilesIfNeeded];
    
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    
//    [[BITHockeyManager sharedHockeyManager] configureWithBetaIdentifier:kBRCHockeyBetaIdentifier
//                                                         liveIdentifier:kBRCHockeyLiveIdentifier delegate:self];
//    [[BITHockeyManager sharedHockeyManager] startManager];
    
    [MGLAccountManager setAccessToken:kBRCMapBoxAccessToken];
    
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    [UIApplication sharedApplication].statusBarHidden = NO;
    
    // Can we set a better interval?
    NSTimeInterval dailyInterval = 24 * 60 * 60; // 24 hours
    [application setMinimumBackgroundFetchInterval:dailyInterval];
    
    [self.dataImporter doubleCheckMapTiles:nil];
    
    [BRCDatabaseManager.shared.backgroundReadConnection asyncReadWithBlock:^(YapDatabaseReadTransaction * __nonnull transaction) {
        NSUInteger campCount = [transaction numberOfKeysInCollection:[BRCCampObject yapCollection]];
        NSUInteger artCount = [transaction numberOfKeysInCollection:[BRCArtObject yapCollection]];
        NSUInteger eventCount = [transaction numberOfKeysInCollection:[BRCEventObject yapCollection]];
        NSLog(@"Existing data: \n%d Art\n%d Camp\n%d Event", (int)artCount, (int)campCount, (int)eventCount);
    }];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"Loading bundled data...");
        [self preloadExistingData];
        NSLog(@"Loading data from internet...");
        NSURL *updatesURL = [NSURL URLWithString:kBRCUpdatesURLString];
        [self.dataImporter loadUpdatesFromURL:updatesURL fetchResultBlock:^(UIBackgroundFetchResult result) {
            NSLog(@"Fetched data from internet with result: %d", (int)result);
        }];
        [ColorCache.shared prefetchAllColors];
    });
    
    //[RMConfiguration sharedInstance].accessToken = @"";
    
    UILocalNotification *launchNotification = [launchOptions objectForKey:UIApplicationLaunchOptionsLocalNotificationKey];
    if (launchNotification) {
        [self application:application didReceiveLocalNotification:launchNotification];
    }
    
    self.locationManager = [CLLocationManager brc_locationManager];
    self.locationManager.delegate = self;
    
    [self setupRegionBasedUnlock];
    [UIApplication sharedApplication].applicationIconBadgeNumber = 0;
    
    [Appirater setAppId:@"388169740"];
    [Appirater setDaysUntilPrompt:2];
    [Appirater setUsesUntilPrompt:5];
    [Appirater setSignificantEventsUntilPrompt:-1];
    [Appirater setTimeBeforeReminding:2];
    [Appirater setCustomAlertTitle:@"We ❤️ You"];
    [Appirater setCustomAlertMessage:@"We put a lot of work into iBurn this year.. so we hope you find it useful! Have a moment to write something nice?"];
    [Appirater setDebug:NO];
    [Appirater setOpenInAppStore:NO];
    [Appirater appLaunched:YES];
    [self setupUnlockNotification];
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor whiteColor];
    _audioDownloader = [[BRCMediaDownloader alloc] initWithConnection:[BRCDatabaseManager.shared.database newConnection] viewName:BRCDatabaseManager.shared.audioTourViewName downloadType:BRCMediaDownloadTypeAudio];
    _imageDownloader = [[BRCMediaDownloader alloc] initWithConnection:[BRCDatabaseManager.shared.database newConnection] viewName:BRCDatabaseManager.shared.artImagesViewName downloadType:BRCMediaDownloadTypeImage];
    
    // Show onboarding.. or not
    BOOL hasViewedOnboarding = [[NSUserDefaults standardUserDefaults] hasViewedOnboarding];
    if (!hasViewedOnboarding) {
        OnboardingViewController *onboardingVC = [[BRCOnboardingViewController alloc] initWithCompletion:^{
            [UIView transitionWithView:self.window
                              duration:1.0
                               options:UIViewAnimationOptionTransitionCrossDissolve
                            animations:^{
                                [self handleOnboardingCompletion];
                            }
                            completion:nil];
        }];
        self.window.rootViewController = onboardingVC;
    } else {
        [self setupNormalRootViewController];
    }
    
    [LocationStorage setup:nil];
    
    [self.window makeKeyAndVisible];
    return YES;
}

- (void) application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification {
    if ([notification.userInfo objectForKey:kBRCGateUnlockNotificationKey]) {
        [[NSUserDefaults standardUserDefaults] scheduleLocalNotificationForGateUnlock:nil];
        [UIApplication sharedApplication].applicationIconBadgeNumber = 0;
    }
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Dismiss" style:UIAlertActionStyleCancel handler:nil];
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil message:notification.alertBody preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:cancelAction];
    
    [self.window.rootViewController presentViewController:alertController animated:YES completion:nil];
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
}

- (void)application:(UIApplication *)application
didReceiveRemoteNotification:(NSDictionary *)userInfo
fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))handler {
    NSURL *updatesURL = [NSURL URLWithString:kBRCUpdatesURLString];
    [self.dataImporter loadUpdatesFromURL:updatesURL fetchResultBlock:handler];
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    DDLogInfo(@"applicationWillTerminate");
}

- (void)application:(UIApplication *)application
performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler {
    NSURL *updatesURL = [NSURL URLWithString:kBRCUpdatesURLString];
    [self.dataImporter loadUpdatesFromURL:updatesURL fetchResultBlock:completionHandler];
}

- (void)application:(UIApplication *)application handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(void (^)(void))completionHandler {
    if ([identifier isEqualToString:kBRCBackgroundFetchIdentifier]) {
        [self.dataImporter addBackgroundURLSessionCompletionHandler:completionHandler];
    } else if ([identifier isEqualToString:self.audioDownloader.backgroundSessionIdentifier]) {
        self.audioDownloader.backgroundCompletion = completionHandler;
    } else if ([identifier isEqualToString:self.imageDownloader.backgroundSessionIdentifier]) {
        self.imageDownloader.backgroundCompletion = completionHandler;
    }
}

- (void) applicationDidReceiveMemoryWarning:(UIApplication *)application {
    DDLogWarn(@"applicationDidReceiveMemoryWarning:");
    [BRCDatabaseManager.shared reduceCacheLimit];
}

- (void)setupDefaultTabBarController
{
    BRCDatabaseManager *dbManager = BRCDatabaseManager.shared;

    self.mapViewController = [[MainMapViewController alloc] init];
    UINavigationController *mapNavController = [[NavigationController alloc] initWithRootViewController:self.mapViewController];
    mapNavController.tabBarItem.image = [UIImage imageNamed:@"BRCMapIcon"];
    
    NearbyViewController *nearbyVC = [[NearbyViewController alloc] initWithStyle:UITableViewStyleGrouped extensionName:BRCDatabaseManager.shared.rTreeIndex];
    nearbyVC.title = @"Nearby";
    UINavigationController *nearbyNav = [[NavigationController alloc] initWithRootViewController:nearbyVC];
    nearbyNav.tabBarItem.image = [UIImage imageNamed:@"BRCCompassIcon"];
    
    self.favoritesViewController = [[FavoritesViewController alloc] initWithViewName:BRCDatabaseManager.shared.everythingFilteredByFavorite searchViewName:BRCDatabaseManager.shared.searchFavoritesView];
    self.favoritesViewController.title = @"Favorites";
    UINavigationController *favoritesNavController = [[NavigationController alloc] initWithRootViewController:self.favoritesViewController];
    favoritesNavController.tabBarItem.image = [UIImage imageNamed:@"BRCHeartIcon"];
    favoritesNavController.tabBarItem.selectedImage = [UIImage imageNamed:@"BRCHeartFilledIcon"];
    
    self.eventsViewController = [[EventListViewController alloc] initWithViewName:dbManager.eventsFilteredByDayExpirationAndTypeViewName searchViewName:dbManager.searchEventsView];
    self.eventsViewController.title = @"Events";
    UINavigationController *eventsNavController = [[NavigationController alloc] initWithRootViewController:self.eventsViewController];
    eventsNavController.tabBarItem.image = [UIImage imageNamed:@"BRCEventIcon"];
    
    UIViewController *moreVC = [MoreViewController fromStoryboard];
    moreVC.title = @"More";
    moreVC.tabBarItem.image = [UIImage imageNamed:@"BRCMoreIcon"];
    
    self.tabBarController = [[UITabBarController alloc] init];
    
    self.tabBarController.viewControllers = @[mapNavController, nearbyNav, favoritesNavController, eventsNavController, moreVC];
    
    self.tabBarController.moreNavigationController.delegate = self;
    self.tabBarController.delegate = self;
}

- (void) setupUnlockNotification {
    NSDate *now = [NSDate present];
    NSDate *festivalStartDate = [BRCEventObject festivalStartDate];
    NSTimeInterval timeLeftInterval = [now timeIntervalSinceDate:festivalStartDate];
    if (timeLeftInterval >= 0) {
        [[NSUserDefaults standardUserDefaults] scheduleLocalNotificationForGateUnlock:nil];
    } else {
        UILocalNotification *existingNotification = [[NSUserDefaults standardUserDefaults] scheduledLocalNotificationForGateUnlock];
        if (existingNotification) {
            return;
        }
        UILocalNotification *unlockNotification = [[UILocalNotification alloc] init];
        unlockNotification.fireDate = festivalStartDate;
        unlockNotification.alertBody = @"Gates are open! Embargoed data can now be unlocked.";
        unlockNotification.soundName = UILocalNotificationDefaultSoundName;
        unlockNotification.alertAction = @"Unlock Now";
        unlockNotification.applicationIconBadgeNumber = 1;
        unlockNotification.userInfo = @{kBRCGateUnlockNotificationKey: @YES};
        [[NSUserDefaults standardUserDefaults] scheduleLocalNotificationForGateUnlock:unlockNotification];
    }
}

- (void) preloadExistingData {
    NSBundle *dataBundle = [NSBundle brc_dataBundle];
    
    NSURL *updateURL = [dataBundle URLForResource:@"update.json" withExtension:@"js"];

    [self.dataImporter loadUpdatesFromURL:updateURL fetchResultBlock:^(UIBackgroundFetchResult result) {
        NSLog(@"Attempted to load pre-existing data with result %d", (int)result);
    }];
    [self.dataImporter waitForDataUpdatesToFinish];
    NSLog(@"Finished loading pre-existing data");
}

- (void) setupRegionBasedUnlock {
    NSParameterAssert(self.locationManager != nil);
    self.burningManRegion = [BRCLocations burningManRegion];
}

- (void) enteredBurningManRegion {
    BRCLocations.hasEnteredBurningManRegion = true;
    if ([BRCEmbargo allowEmbargoedData]) {
        return;
    }
    NSDate *now = [NSDate present];
    NSDate *festivalStartDate = [BRCEventObject festivalStartDate];
    NSTimeInterval timeLeftInterval = [now timeIntervalSinceDate:festivalStartDate];
    if (timeLeftInterval >= 0) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Data Unlocked" message:@"Looks like you're at Burning Man! The restricted data is now unlocked." preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"Sweet!" style:UIAlertActionStyleCancel handler:nil];
        [alert addAction:cancel];
        [self.window.rootViewController presentViewController:alert animated:YES completion:nil];
        [[NSUserDefaults standardUserDefaults] setEnteredEmbargoPasscode:YES];
    }
}

+ (BRCAppDelegate*) shared {
    return (BRCAppDelegate*)[UIApplication sharedApplication].delegate;
}

// Lazy load the data importer
- (BRCDataImporter*) dataImporter {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSURLSessionConfiguration *bgSessionConfiguration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:kBRCBackgroundFetchIdentifier];
        YapDatabaseConnection *connection = [BRCDatabaseManager.shared.database newConnection];
        self->_dataImporter = [[BRCDataImporter alloc] initWithReadWriteConnection:connection sessionConfiguration:bgSessionConfiguration];
    });
    return _dataImporter;
}

#pragma mark CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager
didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    if (status == kCLAuthorizationStatusAuthorizedWhenInUse) {
        [manager startUpdatingLocation];
    } else if (status == kCLAuthorizationStatusDenied || status == kCLAuthorizationStatusRestricted) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Location Services Unavailable" message:@"Please press your iPhone's Home button and go into Settings -> Privacy -> Location and enable location services for iBurn. The app is way better with GPS.\n\np.s. GPS still works during Airplane Mode on iOS 8.3 and higher. Save that battery!" preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"OK I'll totally enable it!" style:UIAlertActionStyleCancel handler:nil];
        [alert addAction:cancel];
        [self.window.rootViewController presentViewController:alert animated:YES completion:nil];
    }
}

- (void) locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
    CLLocation *lastLocation = [locations lastObject];
    if ([self.burningManRegion containsCoordinate:lastLocation.coordinate]) {
        [self enteredBurningManRegion];
    }
    
    // gathering breadcrumbs!
    [BRCDatabaseManager.shared.readWriteConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction * transaction) {
        [locations enumerateObjectsUsingBlock:^(CLLocation *location, NSUInteger idx, BOOL *stop) {
            // only track locations within burning man
            if ([self.burningManRegion containsCoordinate:lastLocation.coordinate]) {
                BRCBreadcrumbPoint *point = [[BRCBreadcrumbPoint alloc] initWithLocation:location];
                if (point) {
                    [point saveWithTransaction:transaction metadata:nil];
                }
            }
        }];
    }];
}

#pragma mark UITabBarControllerDelegate

- (void) tabBarController:(UITabBarController *)tabBarController didSelectViewController:(UIViewController *)viewController {
    if ([viewController isKindOfClass:[UINavigationController class]]) {
        UINavigationController *navController = (UINavigationController*)viewController;
        UIViewController *topViewController = navController.topViewController;
        if ([topViewController isKindOfClass:[MainMapViewController class]]) {
            MainMapViewController *mapViewController = (MainMapViewController*)topViewController;
            if (mapViewController.isVisible) {
                [mapViewController centerMapAtManCoordinatesAnimated:YES];
            }
        }
    }
}

#pragma mark UINavigationControllerDelegate

- (void)navigationController:(UINavigationController *)navigationController
      willShowViewController:(UIViewController *)viewController
                    animated:(BOOL)animated {
    // Remove "Edit" from More tab
    UINavigationBar *morenavbar = navigationController.navigationBar;
    UINavigationItem *morenavitem = morenavbar.topItem;
    morenavitem.rightBarButtonItem = nil;
}

#pragma mark Permissions

/** Asks for remotification permission */
+ (void) registerForRemoteNotifications {
    // Register for Push Notitications
    UIUserNotificationType userNotificationTypes = (UIUserNotificationTypeAlert |
                                                    UIUserNotificationTypeBadge |
                                                    UIUserNotificationTypeSound);
    UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:userNotificationTypes
                                                                             categories:nil];
    [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
    [[UIApplication sharedApplication] registerForRemoteNotifications];
}

/** Asks for location and starts updating */
- (void) requestLocationPermission {
    [self.locationManager requestWhenInUseAuthorization];  // For foreground access
    [self.locationManager startUpdatingLocation];
}

#pragma mark Onboarding

- (void)setupNormalRootViewController {
    [self setupDefaultTabBarController];
    self.window.rootViewController = self.tabBarController;
    
    // do it again just in case
    [[self class] registerForRemoteNotifications];
    [self requestLocationPermission];
}

- (void)handleOnboardingCompletion {
    [[NSUserDefaults standardUserDefaults] setHasViewedOnboarding:YES];
    [self setupNormalRootViewController];
}



@end
