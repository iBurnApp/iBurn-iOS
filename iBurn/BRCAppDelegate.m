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
#import "BRCEmbargoPasscodeViewController.h"
#import "BRCEmbargo.h"
#import "NSUserDefaults+iBurn.h"
#import "BRCEventObject.h"
#import "BRCFilteredTableViewController_Private.h"
#import "BRCDetailViewController.h"
#import "CLLocationManager+iBurn.h"
#import "BRCLocations.h"
#import "UAAppReviewManager.h"
#import "RMConfiguration.h"

static NSString * const kBRCManRegionIdentifier = @"kBRCManRegionIdentifier";
static NSString * const kBRCBackgroundFetchIdentifier = @"kBRCBackgroundFetchIdentifier";

@interface BRCAppDelegate()
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
    [[UIApplication sharedApplication] setStatusBarHidden:NO];
    
    // Can we set a better interval?
    [application setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalMinimum];
    
    
    NSURL *updatesURL = [NSURL URLWithString:kBRCUpdatesURLString];
    [self.dataImporter loadUpdatesFromURL:updatesURL fetchResultBlock:nil];
    
    
    [self setupFestivalDates];
    
    [[BRCDatabaseManager sharedInstance].readWriteConnection readWithBlock:^(YapDatabaseReadTransaction * __nonnull transaction) {
        NSUInteger totalCount = [transaction numberOfKeysInAllCollections];
        if (totalCount == 0) {
            [self preloadExistingData];
        }
    }];
    
    [RMConfiguration sharedInstance].accessToken = @"";
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    [self setupDefaultTabBarController];
    
    if ([BRCEmbargo allowEmbargoedData]) {
        self.window.rootViewController = self.tabBarController;
    } else {
        BRCEmbargoPasscodeViewController *embargoVC = [[BRCEmbargoPasscodeViewController alloc] init];
        embargoVC.dismissAction = ^{
            [UIView transitionWithView:self.window
                              duration:0.5
                               options:UIViewAnimationOptionTransitionFlipFromLeft
                            animations:^{
                                self.window.rootViewController = self.tabBarController;
                            }
                            completion:nil];
        };
        self.window.rootViewController = embargoVC;
    }
    
    UILocalNotification *launchNotification = [launchOptions objectForKey:UIApplicationLaunchOptionsLocalNotificationKey];
    if (launchNotification) {
        [self application:application didReceiveLocalNotification:launchNotification];
    }
    self.locationManager = [CLLocationManager brc_locationManager];
    self.locationManager.delegate = self;
    [self.locationManager startUpdatingLocation];
    [self setupRegionBasedUnlock];
    self.window.backgroundColor = [UIColor whiteColor];
    [UIApplication sharedApplication].applicationIconBadgeNumber = 0;
    [UAAppReviewManager setAppID:@"388169740"];
    [UAAppReviewManager setDaysUntilPrompt:5];
    [UAAppReviewManager setUsesUntilPrompt:5];
    [UAAppReviewManager showPromptIfNecessary];
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
    [self.window.rootViewController presentViewController:alertController animated:YES completion:nil];
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
    [UAAppReviewManager showPromptIfNecessary];
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
    
    self.favoritesViewController = [[BRCFilteredTableViewController alloc] initWithViewClass:[BRCDataObject class] viewName:dbManager.everythingFilteredByFavorite ftsName:dbManager.ftsDataObjectName];
    self.favoritesViewController.title = @"Favorites";
    UINavigationController *favoritesNavController = [[UINavigationController alloc] initWithRootViewController:self.favoritesViewController];
    favoritesNavController.tabBarItem.image = [UIImage imageNamed:@"BRCLightStar"];
    favoritesNavController.tabBarItem.selectedImage = [UIImage imageNamed:@"BRCDarkStar"];
    
    self.artViewController = [[BRCFilteredTableViewController alloc] initWithViewClass:[BRCArtObject class] viewName:dbManager.artViewName ftsName:dbManager.ftsArtName];
    self.artViewController.title = @"Art";
    UINavigationController *artNavController = [[UINavigationController alloc] initWithRootViewController:self.artViewController];
    artNavController.tabBarItem.image = [UIImage imageNamed:@"BRCArtIcon"];
    
    self.campsViewController = [[BRCFilteredTableViewController alloc] initWithViewClass:[BRCCampObject class] viewName:dbManager.campsViewName ftsName:dbManager.ftsCampsName];
    self.campsViewController.title = @"Camps";
    UINavigationController *campNavController = [[UINavigationController alloc] initWithRootViewController:self.campsViewController];
    campNavController.tabBarItem.image = [UIImage imageNamed:@"BRCCampIcon"];
    
    self.eventsViewController = [[BRCEventsTableViewController alloc] initWithViewClass:[BRCEventObject class] viewName:dbManager.eventsFilteredByDayExpirationAndTypeViewName ftsName:dbManager.ftsEventsName];
    self.eventsViewController.title = @"Events";
    UINavigationController *eventsNavController = [[UINavigationController alloc] initWithRootViewController:self.eventsViewController];
    eventsNavController.tabBarItem.image = [UIImage imageNamed:@"BRCEventIcon"];
    
    self.tabBarController = [[UITabBarController alloc] init];
    self.tabBarController.viewControllers = @[mapNavController, favoritesNavController, artNavController, campNavController, eventsNavController];
    self.tabBarController.delegate = self;
}

- (void) setupFestivalDates {
    if ([[NSUserDefaults standardUserDefaults] objectForKey:kBRCStartDateKey]) {
        return;
    }
    NSURL *datesInfoURL = [[NSBundle mainBundle] URLForResource:@"dates_info" withExtension:@"json"];
    NSData *datesInfoData = [NSData dataWithContentsOfURL:datesInfoURL];
    NSDictionary *datesInfoDictionary = [NSJSONSerialization JSONObjectWithData:datesInfoData options:0 error:nil];
    NSDictionary *rangeInfoDictionary = [datesInfoDictionary objectForKey:@"rangeInfo"];
    NSString *startDateString = [rangeInfoDictionary objectForKey:@"startDate"];
    NSDate *startDate = [[NSDateFormatter brc_playaEventsAPIDateFormatter] dateFromString:startDateString];
    NSString *endDateString = [rangeInfoDictionary objectForKey:@"endDate"];
    NSDate *endDate = [[NSDateFormatter brc_playaEventsAPIDateFormatter] dateFromString:endDateString];
    NSArray *majorEventsArray = [datesInfoDictionary objectForKey:@"majorEvents"];
    [[NSUserDefaults standardUserDefaults] setObject:majorEventsArray forKey:kBRCMajorEventsKey];
    [[NSUserDefaults standardUserDefaults] setObject:startDate forKey:kBRCStartDateKey];
    [[NSUserDefaults standardUserDefaults] setObject:endDate forKey:kBRCEndDateKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void) preloadExistingData {
    NSURL *artDataURL = [[NSBundle mainBundle] URLForResource:@"art" withExtension:@"json"];
    NSURL *campsDataURL = [[NSBundle mainBundle] URLForResource:@"camps" withExtension:@"json"];
    NSURL *eventsDataURL = [[NSBundle mainBundle] URLForResource:@"events" withExtension:@"json"];

    NSArray *dataToLoad = @[@[artDataURL, [BRCArtObject class]],
                            @[campsDataURL, [BRCCampObject class]],
                            @[eventsDataURL, [BRCRecurringEventObject class]]];
    
    [dataToLoad enumerateObjectsUsingBlock:^(NSArray *obj, NSUInteger idx, BOOL *stop) {
        NSURL *url = [obj firstObject];
        Class dataClass = [obj lastObject];
        NSData *data = [[NSData alloc] initWithContentsOfURL:url];
        NSError *error = nil;
        BOOL success = [self.dataImporter loadDataFromJSONData:data dataClass:dataClass error:&error];
        if (!success) {
            NSLog(@"Error importing %@ data: %@", NSStringFromClass(dataClass), error);
        } else {
            NSLog(@"Imported %@ data successfully", NSStringFromClass(dataClass));
        }
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
        if ([self.window.rootViewController isKindOfClass:[BRCEmbargoPasscodeViewController class]]) {
            BRCEmbargoPasscodeViewController *embargoVC = (BRCEmbargoPasscodeViewController*)self.window.rootViewController;
            [embargoVC setUnlocked];
        }
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

@end
