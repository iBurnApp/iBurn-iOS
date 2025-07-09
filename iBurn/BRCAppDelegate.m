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
#import "iBurn-Swift.h"
#import "NSUserDefaults+iBurn.h"
#import "BRCBreadcrumbPoint.h"
#import "BRCDataImporter_Private.h"
@import PermissionScope;
#import "NSDate+iBurn.h"
@import AVFoundation;
@import CocoaLumberjack;
@import FirebaseCore;
#import "iBurn-Swift.h"
@import UserNotifications;
@import BackgroundTasks;

static int ddLogLevel = DDLogLevelVerbose;

static NSString * const kBRCBackgroundFetchIdentifier = @"kBRCBackgroundFetchIdentifier";

@interface BRCAppDelegate() <UINavigationControllerDelegate, UNUserNotificationCenterDelegate>
@property (nonatomic, strong) CLCircularRegion *burningManRegion;
@property (nonatomic, strong, readonly) BRCMediaDownloader *audioDownloader;
@property (nonatomic, strong, readonly) BRCMediaDownloader *imageDownloader;

@end

@implementation BRCAppDelegate
@synthesize dataImporter = _dataImporter;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [FIRApp configure];
    [Appearance setGlobalAppearance];
    
    // Set up notification center delegate
    UNUserNotificationCenter.currentNotificationCenter.delegate = self;
    
    // Request notification authorization
    [UNUserNotificationCenter.currentNotificationCenter requestAuthorizationWithOptions:(UNAuthorizationOptionAlert | UNAuthorizationOptionBadge | UNAuthorizationOptionSound) completionHandler:^(BOOL granted, NSError * _Nullable error) {
        if (granted) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[UIApplication sharedApplication] registerForRemoteNotifications];
            });
        }
    }];
    
    // Register background fetch task
    [[BGTaskScheduler sharedScheduler] registerForTaskWithIdentifier:kBRCBackgroundFetchIdentifier usingQueue:nil launchHandler:^(__kindof BGTask * _Nonnull task) {
        [self handleBackgroundFetch:(BGAppRefreshTask *)task];
    }];
    
    // Schedule background fetch
    [self scheduleBackgroundFetch];
    
#if DEBUG
    [DDLog addLogger:[DDTTYLogger sharedInstance]];

    DDFileLogger *fileLogger = [[DDFileLogger alloc] init];
    fileLogger.doNotReuseLogFiles = YES;
    [DDLog addLogger:fileLogger withLevel:DDLogLevelAll];
#endif
            
    // Background fetch is now handled by BackgroundTasks framework
    // [application setMinimumBackgroundFetchInterval:dailyInterval];
        
    [BRCDatabaseManager.shared.backgroundReadConnection asyncReadWithBlock:^(YapDatabaseReadTransaction * __nonnull transaction) {
        NSUInteger campCount = [transaction numberOfKeysInCollection:[BRCCampObject yapCollection]];
        NSUInteger artCount = [transaction numberOfKeysInCollection:[BRCArtObject yapCollection]];
        NSUInteger eventCount = [transaction numberOfKeysInCollection:[BRCEventObject yapCollection]];
        NSLog(@"Existing data: \n%d Art\n%d Camp\n%d Event", (int)artCount, (int)campCount, (int)eventCount);
    }];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"Loading bundled data...");
        [self preloadExistingData];
        if ([NSUserDefaults areDownloadsDisabled]) {
            NSLog(@"Downloads are disabled, skipping.");
            return;
        }
        NSLog(@"Loading data from internet...");
        NSURL *updatesURL = [NSURL URLWithString:kBRCUpdatesURLString];
        [self.dataImporter loadUpdatesFromURL:updatesURL fetchResultBlock:^(UIBackgroundFetchResult result) {
            NSLog(@"Fetched data from internet with result: %d", (int)result);
        }];
        [ColorCache.shared prefetchAllColors];
    });
    
    // Handle launch from notification
    if (launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey]) {
        [self handleNotification:launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey]];
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
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = UIColor.systemBackgroundColor;
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

#pragma mark - UNUserNotificationCenterDelegate

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler
{
    // Show notification even when app is in foreground
    completionHandler(UNNotificationPresentationOptionBanner | UNNotificationPresentationOptionSound);
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
didReceiveNotificationResponse:(UNNotificationResponse *)response
         withCompletionHandler:(void(^)(void))completionHandler
{
    [self handleNotification:response.notification];
    completionHandler();
}

- (void)handleNotification:(UNNotification *)notification {
    // Handle notification content
    UNNotificationContent *content = notification.request.content;
    NSString *title = content.title;
    NSString *body = content.body;
    
    // Present alert
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                 message:body
                                                          preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK"
                                                      style:UIAlertActionStyleDefault
                                                    handler:nil];
    [alert addAction:okAction];
    
    // Get the active window scene and its root view controller
    UIWindowScene *windowScene = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if ([scene isKindOfClass:[UIWindowScene class]]) {
            windowScene = (UIWindowScene *)scene;
            break;
        }
    }
    
    UIViewController *rootVC = windowScene.windows.firstObject.rootViewController;
    [rootVC presentViewController:alert animated:YES completion:nil];
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
    
    self.tabBarController = [[TabController alloc] init];
    
    self.tabBarController.viewControllers = @[mapNavController, nearbyNav, favoritesNavController, eventsNavController, moreVC];
    
    self.tabBarController.moreNavigationController.delegate = self;
    self.tabBarController.delegate = self;
}

- (void) preloadExistingData {
    NSBundle *dataBundle = [NSBundle brc_dataBundle];
    
    NSURL *updateURL = [dataBundle URLForResource:@"update" withExtension:@"json"];

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

- (void)locationManagerDidChangeAuthorization:(CLLocationManager *)manager {
    CLAuthorizationStatus status = manager.authorizationStatus;
    if (status == kCLAuthorizationStatusAuthorizedWhenInUse || status == kCLAuthorizationStatusAuthorizedAlways) {
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
    // Register for Push Notifications
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

    // Present Embargo Screen if needed
    if (![BRCEmbargo allowEmbargoedData]) {
        UIViewController *hostingController = [EmbargoPasscodeFactory makeViewControllerWithDismissAction:^{
            [self.tabBarController dismissViewControllerAnimated:YES completion:nil];
        }];
        hostingController.modalPresentationStyle = UIModalPresentationFullScreen;
        [self.tabBarController presentViewController:hostingController animated:YES completion:nil];
    }
}

- (void)handleOnboardingCompletion {
    [[NSUserDefaults standardUserDefaults] setHasViewedOnboarding:YES];
    [self setupNormalRootViewController];
}

- (void)scheduleBackgroundFetch {
    BGAppRefreshTaskRequest *request = [[BGAppRefreshTaskRequest alloc] initWithIdentifier:kBRCBackgroundFetchIdentifier];
    request.earliestBeginDate = [NSDate dateWithTimeIntervalSinceNow:24 * 60 * 60]; // 24 hours
    
    NSError *error = nil;
    [[BGTaskScheduler sharedScheduler] submitTaskRequest:request error:&error];
    if (error) {
        DDLogError(@"Could not schedule background fetch: %@", error);
    }
}

- (void)handleBackgroundFetch:(BGAppRefreshTask *)task {
    // Schedule the next background fetch
    [self scheduleBackgroundFetch];
    
    if ([NSUserDefaults areDownloadsDisabled]) {
        DDLogInfo(@"Downloads are disabled, skipping.");
        [task setTaskCompletedWithSuccess:YES];
        return;
    }
    
    NSURL *updatesURL = [NSURL URLWithString:kBRCUpdatesURLString];
    [self.dataImporter loadUpdatesFromURL:updatesURL fetchResultBlock:^(UIBackgroundFetchResult result) {
        BOOL success = (result == UIBackgroundFetchResultNewData);
        [task setTaskCompletedWithSuccess:success];
    }];
}

@end
