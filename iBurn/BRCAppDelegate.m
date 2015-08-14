//
//  BRCAppDelegate.m
//  iBurn
//
//  Created by David Chiles on 7/28/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCAppDelegate.h"
#import "BRCMapViewController.h"
#import "BRCEventsTableViewController.h"
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
#import "BRCFilteredTableViewController_Private.h"
#import "BRCDetailViewController.h"
#import "CLLocationManager+iBurn.h"
#import "BRCLocations.h"
#import "Appirater.h"
#import "RMConfiguration.h"
@import JSQWebViewController;
#import <Parse/Parse.h>
#import "TUSafariActivity.h"
#import <WebKit/WebKit.h>
@import TTTAttributedLabel;
#import "BRCAcknowledgementsViewController.h"
#import "BRCEmbargoPasscodeViewController.h"
#import "iBurn-Swift.h"
#import "NSBundle+iBurn.h"
#import "NSUserDefaults+iBurn.h"
@import Onboard;
@import PermissionScope;

static NSString * const kBRCManRegionIdentifier = @"kBRCManRegionIdentifier";
static NSString * const kBRCBackgroundFetchIdentifier = @"kBRCBackgroundFetchIdentifier";

@interface BRCAppDelegate() <UINavigationControllerDelegate>
@property (nonatomic, strong) CLCircularRegion *burningManRegion;
@property (nonatomic, strong, readonly) BRCDataImporter *dataImporter;
@end

@implementation BRCAppDelegate
@synthesize dataImporter = _dataImporter;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [[BITHockeyManager sharedHockeyManager] configureWithBetaIdentifier:kBRCHockeyBetaIdentifier
                                                         liveIdentifier:kBRCHockeyLiveIdentifier delegate:self];
    [[BITHockeyManager sharedHockeyManager] startManager];
    
    [Parse setApplicationId:kBRCParseApplicationId
                  clientKey:kBRCParseClientKey];
    
    [PFNetworkActivityIndicatorManager sharedManager].enabled = NO;
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    [UIApplication sharedApplication].statusBarHidden = NO;
    
    // Can we set a better interval?
    NSTimeInterval dailyInterval = 24 * 60 * 60; // 24 hours
    [application setMinimumBackgroundFetchInterval:dailyInterval];
    
    NSURL *updatesURL = [NSURL URLWithString:kBRCUpdatesURLString];
    [self.dataImporter loadUpdatesFromURL:updatesURL fetchResultBlock:nil];
    
    [self setupFestivalDates];
    
    [[BRCDatabaseManager sharedInstance].readWriteConnection readWithBlock:^(YapDatabaseReadTransaction * __nonnull transaction) {
        NSUInteger campCount = [transaction numberOfKeysInCollection:[BRCCampObject collection]];
        NSUInteger artCount = [transaction numberOfKeysInCollection:[BRCArtObject collection]];
        NSUInteger eventCount = [transaction numberOfKeysInCollection:[BRCEventObject collection]];
        NSLog(@"\n%d Art\n%d Camp\n%d Event", (int)artCount, (int)campCount, (int)eventCount);
        if (campCount == 0 || artCount == 0 || eventCount == 0) {
            [self preloadExistingData];
        }
    }];
    
    [RMConfiguration sharedInstance].accessToken = @"";
    [PFAnalytics trackAppOpenedWithLaunchOptions:launchOptions];
    
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
    [Appirater setCustomAlertTitle:@"We Love You"];
    [Appirater setCustomAlertMessage:@"We put a lot of work into iBurn this year.. so we hope you find it useful! Have a moment to write something nice?"];
    [Appirater setDebug:NO];
    [Appirater setOpenInAppStore:NO];
    [Appirater appLaunched:YES];
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor whiteColor];
    
    // Show onboarding.. or not
    BOOL hasViewedOnboarding = [[NSUserDefaults standardUserDefaults] hasViewedOnboarding];
    if (!hasViewedOnboarding) {
        OnboardingViewController *onboardingVC = [[self class] onboardingViewControllerWithCompletion:^{
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
    if (notification.alertAction.length > 0) {
        NSString *eventKey = [BRCEventObject localNotificationUserInfoKey];
        NSString *eventUniqueID = [notification.userInfo objectForKey:eventKey];
        UIAlertAction *actionItem = [UIAlertAction actionWithTitle:notification.alertAction style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            if (!eventUniqueID) {
                return;
            }
            [self.tabBarController setSelectedViewController:self.eventsViewController.navigationController];
            __block BRCEventObject *event = nil;
            [self.eventsViewController.databaseConnection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction) {
                event = [transaction objectForKey:eventUniqueID inCollection:[BRCEventObject collection]];
            } completionBlock:^{
                if (event) {
                    BRCDetailViewController *detailVC = [[BRCDetailViewController alloc] initWithDataObject:event];
                    [self.eventsViewController.navigationController pushViewController:detailVC animated:YES];
                }
            }];
        }];
        [alertController addAction:actionItem];
    }
    [self setupUnlockNotification];
    [self.window.rootViewController presentViewController:alertController animated:YES completion:nil];
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    // Store the deviceToken in the current installation and save it to Parse.
    PFInstallation *currentInstallation = [PFInstallation currentInstallation];
    [currentInstallation setDeviceTokenFromData:deviceToken];
    currentInstallation.channels = @[ @"global", @"updates" ];
    [currentInstallation saveInBackground];
}

- (void)application:(UIApplication *)application
didReceiveRemoteNotification:(NSDictionary *)userInfo
fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))handler {
    [PFAnalytics trackAppOpenedWithRemoteNotificationPayload:userInfo];
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
}

- (void)application:(UIApplication *)application
performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler {
    NSURL *updatesURL = [NSURL URLWithString:kBRCUpdatesURLString];
    [self.dataImporter loadUpdatesFromURL:updatesURL fetchResultBlock:completionHandler];
}

- (void)application:(UIApplication *)application handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(void (^)())completionHandler
{
    [self.dataImporter addBackgroundURLSessionCompletionHandler:completionHandler];
}

- (void)setupDefaultTabBarController
{
    BRCDatabaseManager *dbManager = [BRCDatabaseManager sharedInstance];

    self.mapViewController = [[BRCMapViewController alloc] initWithFtsName:dbManager.ftsDataObjectName];
    UINavigationController *mapNavController = [[UINavigationController alloc] initWithRootViewController:self.mapViewController];
    mapNavController.tabBarItem.image = [UIImage imageNamed:@"BRCMapIcon"];
    
    BRCNearbyViewController *nearbyVC = [[BRCNearbyViewController alloc] initWithStyle:UITableViewStyleGrouped];
    nearbyVC.title = @"Nearby";
    UINavigationController *nearbyNav = [[UINavigationController alloc] initWithRootViewController:nearbyVC];
    nearbyNav.tabBarItem.image = [UIImage imageNamed:@"BRCCompassIcon"];
    
    self.favoritesViewController = [[BRCFilteredTableViewController alloc] initWithViewClass:[BRCDataObject class] viewName:dbManager.everythingFilteredByFavorite searchViewName:dbManager.searchFavoritesView];
    self.favoritesViewController.title = @"Favorites";
    UINavigationController *favoritesNavController = [[UINavigationController alloc] initWithRootViewController:self.favoritesViewController];
    favoritesNavController.tabBarItem.image = [UIImage imageNamed:@"BRCHeartIcon"];
    favoritesNavController.tabBarItem.selectedImage = [UIImage imageNamed:@"BRCHeartFilledIcon"];
    
    
    self.eventsViewController = [[BRCEventsTableViewController alloc] initWithViewClass:[BRCEventObject class] viewName:dbManager.eventsFilteredByDayExpirationAndTypeViewName searchViewName:dbManager.searchEventsView];
    self.eventsViewController.title = @"Events";
    UINavigationController *eventsNavController = [[UINavigationController alloc] initWithRootViewController:self.eventsViewController];
    eventsNavController.tabBarItem.image = [UIImage imageNamed:@"BRCEventIcon"];
    
    UIViewController *moreVC = [UIStoryboard storyboardWithName:@"More" bundle:[NSBundle mainBundle]].instantiateInitialViewController;
    moreVC.title = @"More";
    moreVC.tabBarItem.image = [UIImage imageNamed:@"BRCMoreIcon"];
    
    self.tabBarController = [[UITabBarController alloc] init];
    
    self.tabBarController.viewControllers = @[mapNavController, nearbyNav, favoritesNavController, eventsNavController, moreVC];
    
    self.tabBarController.moreNavigationController.delegate = self;
    self.tabBarController.delegate = self;
}

- (void) setupUnlockNotification {
    NSDate *now = [NSDate date];
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

- (void) setupFestivalDates {
    if ([[NSUserDefaults standardUserDefaults] objectForKey:kBRCStartDate2015Key]) {
        return;
    }
    NSBundle *dataBundle = [NSBundle brc_dataBundle];
    NSURL *datesInfoURL = [dataBundle URLForResource:@"dates_info" withExtension:@"json"];
    NSData *datesInfoData = [NSData dataWithContentsOfURL:datesInfoURL];
    NSDictionary *datesInfoDictionary = [NSJSONSerialization JSONObjectWithData:datesInfoData options:0 error:nil];
    NSDictionary *rangeInfoDictionary = [datesInfoDictionary objectForKey:@"rangeInfo"];
    NSString *startDateString = [rangeInfoDictionary objectForKey:@"startDate"];
    NSDate *startDate = [[NSDateFormatter brc_playaEventsAPIDateFormatter] dateFromString:startDateString];
    NSString *endDateString = [rangeInfoDictionary objectForKey:@"endDate"];
    NSDate *endDate = [[NSDateFormatter brc_playaEventsAPIDateFormatter] dateFromString:endDateString];
    NSArray *majorEventsArray = [datesInfoDictionary objectForKey:@"majorEvents"];
    [[NSUserDefaults standardUserDefaults] setObject:majorEventsArray forKey:kBRCMajorEvents2015Key];
    [[NSUserDefaults standardUserDefaults] setObject:startDate forKey:kBRCStartDate2015Key];
    [[NSUserDefaults standardUserDefaults] setObject:endDate forKey:kBRCEndDate2015Key];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void) preloadExistingData {
    NSBundle *dataBundle = [NSBundle brc_dataBundle];
    
    NSURL *updateURL = [dataBundle URLForResource:@"update.json" withExtension:@"js"];

    [self.dataImporter loadUpdatesFromURL:updateURL fetchResultBlock:^(UIBackgroundFetchResult result) {
        NSLog(@"Attempted to load pre-existing data with result %d", (int)result);
    }];
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
    if([[BITHockeyManager sharedHockeyManager].authenticator handleOpenURL:url
                                                          sourceApplication:sourceApplication
                                                                 annotation:annotation]) {
        return YES;
    }
    return NO;
}

- (void) setupRegionBasedUnlock {
    NSParameterAssert(self.locationManager != nil);
    CLLocationCoordinate2D manCoordinate2014 = [BRCLocations blackRockCityCenter];
    CLLocationDistance radius = 5 * 8046.72; // Within 5 miles of the man
    self.burningManRegion = [[CLCircularRegion alloc] initWithCenter:manCoordinate2014 radius:radius identifier:kBRCManRegionIdentifier];
}

- (void)locationManager:(CLLocationManager *)manager
didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    if (status == kCLAuthorizationStatusAuthorizedWhenInUse) {
        [manager startUpdatingLocation];
    } else if (status == kCLAuthorizationStatusDenied || status == kCLAuthorizationStatusRestricted) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Location Services Unavailable" message:@"Please press your iPhone's Home button and go into Settings -> Privacy -> Location and enable location services for iBurn. The app is way better with GPS.\n\np.s. GPS still works during Airplane Mode on iOS 8.3 and higher. Save that battery!" delegate:nil cancelButtonTitle:@"OK I'll totally enable it!" otherButtonTitles:nil];
        [alert show];

    }
}

- (void) locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
    CLLocation *lastLocation = [locations lastObject];
    if ([self.burningManRegion containsCoordinate:lastLocation.coordinate]) {
        [self enteredBurningManRegion];
    }
}

- (void) enteredBurningManRegion {
    [PFAnalytics trackEventInBackground:@"Entered_Burning_Man" block:nil];
    if ([BRCEmbargo allowEmbargoedData]) {
        return;
    }
    NSDate *now = [NSDate date];
    NSDate *festivalStartDate = [BRCEventObject festivalStartDate];
    NSTimeInterval timeLeftInterval = [now timeIntervalSinceDate:festivalStartDate];
    if (timeLeftInterval >= 0) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Data Unlocked" message:@"Looks like you're at Burning Man! The restricted data is now unlocked." delegate:nil cancelButtonTitle:@"Sweet!" otherButtonTitles:nil];
        [alert show];
        [[NSUserDefaults standardUserDefaults] setEnteredEmbargoPasscode:YES];
    }
}

+ (instancetype) sharedAppDelegate {
    return (BRCAppDelegate*)[UIApplication sharedApplication].delegate;
}

// Lazy load the data importer
- (BRCDataImporter*) dataImporter {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSURLSessionConfiguration *bgSessionConfiguration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:kBRCBackgroundFetchIdentifier];
        YapDatabaseConnection *connection = [[BRCDatabaseManager sharedInstance].database newConnection];
        _dataImporter = [[BRCDataImporter alloc] initWithReadWriteConnection:connection sessionConfiguration:bgSessionConfiguration];
    });
    return _dataImporter;
}

+ (void) openURL:(NSURL*)url fromViewController:(UIViewController*)viewController {
    if (!url || !viewController) {
        return;
    }
    NSParameterAssert(url);
    NSParameterAssert(viewController);
    NSOperatingSystemVersion iosVersion = {.majorVersion = 9};
    if ([[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:iosVersion]) {
        [[UIApplication sharedApplication] openURL:url];
    } else {
        TUSafariActivity *activity = [[TUSafariActivity alloc] init];
        NSURLRequest *request = [NSURLRequest requestWithURL:url];
        WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
        WebViewController *wvc = [[WebViewController alloc] initWithUrlRequest:request configuration:configuration activities:@[activity]];
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:wvc];
        [viewController presentViewController:nav animated:YES completion:NULL];
    }
}

#pragma mark UITabBarControllerDelegate

- (void) tabBarController:(UITabBarController *)tabBarController didSelectViewController:(UIViewController *)viewController {
    if ([viewController isKindOfClass:[UINavigationController class]]) {
        UINavigationController *navController = (UINavigationController*)viewController;
        UIViewController *topViewController = navController.topViewController;
        if ([topViewController isKindOfClass:[BRCMapViewController class]]) {
            BRCMapViewController *mapViewController = (BRCMapViewController*)topViewController;
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

/** Returns newly configured onboarding view */
+ (OnboardingViewController *)onboardingViewControllerWithCompletion:(dispatch_block_t)completionBlock {
    OnboardingContentViewController *firstPage = [OnboardingContentViewController contentWithTitle:@"Welcome to iBurn" body:@"\nLet's get started!" image:nil buttonText:@"📍 Enable Location Services" action:^{
        [BRCPermissions promptForLocation:^{
            NSLog(@"BRCPermissions promptForLocation");
            //[firstPage.delegate moveNextPage];
        }];
    }];
    firstPage.movesToNextViewController = YES;
    
    OnboardingContentViewController *secondPage = [OnboardingContentViewController contentWithTitle:@"Reminders" body:@"When you favorite events we can remind you about them later." image:nil buttonText:@"⏰ Enable Notifications" action:^{
        [BRCPermissions promptForPush:^{
            NSLog(@"BRCPermissions promptForPush");
            //[secondPage.delegate moveNextPage];
        }];
    }];
    secondPage.movesToNextViewController = YES;
    
    OnboardingContentViewController *thirdPage = [OnboardingContentViewController contentWithTitle:@"Thank you!" body:@"If you enjoy using iBurn, please spread the word." image:nil buttonText:@"Ok let's go!" action:completionBlock];
    
    NSBundle *bundle = [NSBundle mainBundle];
    NSString *moviePath = [bundle pathForResource:@"onboarding_loop" ofType:@"mp4"];
    NSURL *movieURL = [NSURL fileURLWithPath:moviePath];
    
    OnboardingViewController *onboardingVC = [[OnboardingViewController alloc] initWithBackgroundVideoURL:movieURL contents:@[firstPage, secondPage, thirdPage]];
    onboardingVC.shouldFadeTransitions = YES;
    onboardingVC.fadePageControlOnLastPage = YES;
    onboardingVC.stopMoviePlayerWhenDisappear = YES;
    onboardingVC.moviePlayerController.scalingMode = MPMovieScalingModeAspectFill;
    
    // If you want to allow skipping the onboarding process, enable skipping and set a block to be executed
    // when the user hits the skip button.
    // onboardingVC.allowSkipping = YES;
    onboardingVC.skipHandler = completionBlock;
    
    return onboardingVC;
}

@end
