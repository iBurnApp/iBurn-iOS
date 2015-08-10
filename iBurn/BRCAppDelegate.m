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
    
    [[UIApplication sharedApplication] setStatusBarHidden:NO];
    
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
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    [self setupDefaultTabBarController];
    
    self.window.rootViewController = self.tabBarController;
    
    UILocalNotification *launchNotification = [launchOptions objectForKey:UIApplicationLaunchOptionsLocalNotificationKey];
    if (launchNotification) {
        [self application:application didReceiveLocalNotification:launchNotification];
    }
    self.locationManager = [CLLocationManager brc_locationManager];
    self.locationManager.delegate = self;
    [self.locationManager requestWhenInUseAuthorization];  // For foreground access
    [self.locationManager startUpdatingLocation];
    [self setupRegionBasedUnlock];
    self.window.backgroundColor = [UIColor whiteColor];
    [UIApplication sharedApplication].applicationIconBadgeNumber = 0;
    
    [Appirater setAppId:@"388169740"];
    [Appirater setDaysUntilPrompt:5];
    [Appirater setUsesUntilPrompt:5];
    [Appirater setSignificantEventsUntilPrompt:-1];
    [Appirater setTimeBeforeReminding:2];
    [Appirater setDebug:NO];
    [Appirater appLaunched:YES];
    
    // Register for Push Notitications
    UIUserNotificationType userNotificationTypes = (UIUserNotificationTypeAlert |
                                                    UIUserNotificationTypeBadge |
                                                    UIUserNotificationTypeSound);
    UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:userNotificationTypes
                                                                             categories:nil];
    [application registerUserNotificationSettings:settings];
    [application registerForRemoteNotifications];
    [PFAnalytics trackAppOpenedWithLaunchOptions:launchOptions];
    
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
    if ([userInfo[@"aps"][@"content-available"] boolValue]) {
        NSURL *updatesURL = [NSURL URLWithString:kBRCUpdatesURLString];
        [self.dataImporter loadUpdatesFromURL:updatesURL fetchResultBlock:handler];
    } else {
        handler(UIBackgroundFetchResultNoData);
    }
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
    
    UITableViewController *nearbyVC = [[UITableViewController alloc] initWithStyle:UITableViewStyleGrouped];
    nearbyVC.title = @"Nearby";
    UINavigationController *nearbyNav = [[UINavigationController alloc] initWithRootViewController:nearbyVC];
    nearbyNav.tabBarItem.image = [UIImage imageNamed:@"BRCCompassIcon"];
    
    self.favoritesViewController = [[BRCFilteredTableViewController alloc] initWithViewClass:[BRCDataObject class] viewName:dbManager.everythingFilteredByFavorite searchViewName:dbManager.searchFavoritesView];
    self.favoritesViewController.title = @"Favorites";
    UINavigationController *favoritesNavController = [[UINavigationController alloc] initWithRootViewController:self.favoritesViewController];
    favoritesNavController.tabBarItem.image = [UIImage imageNamed:@"BRCHeartIcon"];
    favoritesNavController.tabBarItem.selectedImage = [UIImage imageNamed:@"BRCHeartFilledIcon"];
    
    self.artViewController = [[BRCFilteredTableViewController alloc] initWithViewClass:[BRCArtObject class] viewName:dbManager.artViewName searchViewName:dbManager.searchArtView];
    self.artViewController.title = @"Art";
    UINavigationController *artNavController = [[UINavigationController alloc] initWithRootViewController:self.artViewController];
    artNavController.tabBarItem.image = [UIImage imageNamed:@"BRCArtIcon"];
    
    self.campsViewController = [[BRCFilteredTableViewController alloc] initWithViewClass:[BRCCampObject class] viewName:dbManager.campsViewName searchViewName:dbManager.searchCampsView];
    self.campsViewController.title = @"Camps";
    UINavigationController *campNavController = [[UINavigationController alloc] initWithRootViewController:self.campsViewController];
    campNavController.tabBarItem.image = [UIImage imageNamed:@"BRCCampIcon"];
    
    self.eventsViewController = [[BRCEventsTableViewController alloc] initWithViewClass:[BRCEventObject class] viewName:dbManager.eventsFilteredByDayExpirationAndTypeViewName searchViewName:dbManager.searchEventsView];
    self.eventsViewController.title = @"Events";
    UINavigationController *eventsNavController = [[UINavigationController alloc] initWithRootViewController:self.eventsViewController];
    eventsNavController.tabBarItem.image = [UIImage imageNamed:@"BRCEventIcon"];
    
    BRCAcknowledgementsViewController *ackVC = [self acknowledgementsViewController];
    ackVC.title = @"Open Source";
    UINavigationController *ackNav = [[UINavigationController alloc] initWithRootViewController:ackVC];
    ackNav.tabBarItem.image = [UIImage imageNamed:@"BRCGitHubIcon"];
    
    BRCEmbargoPasscodeViewController *unlockVC = [[BRCEmbargoPasscodeViewController alloc] init];
    __weak BRCEmbargoPasscodeViewController *weakUnlock = unlockVC;
    unlockVC.dismissAction = ^{
        [weakUnlock.navigationController popViewControllerAnimated:YES];
    };
    unlockVC.title = @"Unlock Location Data";
    unlockVC.tabBarItem.image = [UIImage imageNamed:@"BRCLockIcon"];
    
    UITableViewController *debugVC = [[UITableViewController alloc] initWithStyle:UITableViewStyleGrouped];
    debugVC.title = @"Debug";
    UINavigationController *debugNav = [[UINavigationController alloc] initWithRootViewController:debugVC];
    debugNav.tabBarItem.image = [UIImage imageNamed:@"BRCDebugIcon"];
    
    UITableViewController *creditsVC = [[UITableViewController alloc] initWithStyle:UITableViewStyleGrouped];
    creditsVC.title = @"Credits";
    UINavigationController *creditsNav = [[UINavigationController alloc] initWithRootViewController:creditsVC];
    creditsNav.tabBarItem.image = [UIImage imageNamed:@"BRCCreditsIcon"];
    
    self.tabBarController = [[UITabBarController alloc] init];
    self.tabBarController.viewControllers = @[mapNavController, nearbyNav, favoritesNavController, eventsNavController, artNavController, campNavController, ackNav, creditsNav, unlockVC, debugNav];
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

- (BRCAcknowledgementsViewController*) acknowledgementsViewController {
    CGFloat labelMargin = 10;
    TTTAttributedLabel *headerLabel = [[TTTAttributedLabel alloc] initWithFrame:CGRectZero];
    NSString *chrisballingerString = @"@chrisballinger";
    NSURL *chrisballingerURL = [NSURL URLWithString:@"https://github.com/chrisballinger"];
    NSString *davidchilesString = @"@davidchiles";
    NSURL *davidChilesURL = [NSURL URLWithString:@"https://github.com/davidchiles"];
    NSString *headerText = [NSString stringWithFormat:@"Crafted with ❤ by %@ & %@.", chrisballingerString, davidchilesString];
    NSRange chrisRange = [headerText rangeOfString:chrisballingerString];
    NSRange davidRange = [headerText rangeOfString:davidchilesString];
    
    UIFont *font = [UIFont systemFontOfSize:12];
    CGFloat labelWidth = CGRectGetWidth(self.window.bounds) - 2 * labelMargin;
    CGFloat labelHeight;
    
    NSStringDrawingOptions options = (NSLineBreakByWordWrapping | NSStringDrawingUsesLineFragmentOrigin);
    CGRect labelBounds = [headerText boundingRectWithSize:CGSizeMake(labelWidth, CGFLOAT_MAX)
                                                  options:options
                                               attributes:@{NSFontAttributeName: font}
                                                  context:nil];
    labelHeight = CGRectGetHeight(labelBounds) + 5; // emoji hearts are big
    
    CGRect labelFrame = CGRectMake(labelMargin, labelMargin*2, labelWidth, labelHeight);
    
    NSDictionary *linkAttributes = @{(NSString*)kCTForegroundColorAttributeName:(id)[[UIColor blackColor] CGColor],
                                     (NSString *)kCTUnderlineStyleAttributeName: @NO};
    headerLabel.linkAttributes = linkAttributes;
    
    headerLabel.frame = labelFrame;
    headerLabel.font             = font;
    headerLabel.textColor        = [UIColor grayColor];
    headerLabel.backgroundColor  = [UIColor clearColor];
    headerLabel.numberOfLines    = 0;
    headerLabel.textAlignment    = NSTextAlignmentCenter;
    headerLabel.autoresizingMask = (UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin);
    headerLabel.text = headerText;
    
    [headerLabel addLinkToURL:chrisballingerURL withRange:chrisRange];
    [headerLabel addLinkToURL:davidChilesURL withRange:davidRange];
    
    BRCAcknowledgementsViewController *viewController = [[BRCAcknowledgementsViewController alloc] initWithHeaderLabel:headerLabel];
    return viewController;
}

- (void) setupFestivalDates {
    if ([[NSUserDefaults standardUserDefaults] objectForKey:kBRCStartDate2015Key]) {
        return;
    }
    NSString *folderName = @"2015";
    NSString *bundlePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:folderName];
    NSBundle *dataBundle = [NSBundle bundleWithPath:bundlePath];
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
    NSString *folderName = @"2015";
    NSString *bundlePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:folderName];
    NSBundle *dataBundle = [NSBundle bundleWithPath:bundlePath];
    
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

- (void)navigationController:(UINavigationController *)navigationController
      willShowViewController:(UIViewController *)viewController
                    animated:(BOOL)animated {
    
    UINavigationBar *morenavbar = navigationController.navigationBar;
    UINavigationItem *morenavitem = morenavbar.topItem;
    /* We don't need Edit button in More screen. */
    morenavitem.rightBarButtonItem = nil;
}

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

+ (instancetype) appDelegate {
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

@end
