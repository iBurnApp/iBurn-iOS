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
#import "UIAlertView+Blocks.h"
#import "BRCFilteredTableViewController_Private.h"
#import "BRCDetailViewController.h"
#import "CLLocationManager+iBurn.h"
#import "BRCLocations.h"
#import "UAAppReviewManager.h"

static NSString * const kBRCManRegionIdentifier = @"kBRCManRegionIdentifier";

@interface BRCAppDelegate()
@property (nonatomic, strong) CLCircularRegion *burningManRegion;
@end

@implementation BRCAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [[BITHockeyManager sharedHockeyManager] configureWithBetaIdentifier:kBRCHockeyBetaIdentifier
                                                         liveIdentifier:kBRCHockeyLiveIdentifier delegate:self];
    [[BITHockeyManager sharedHockeyManager].authenticator setIdentificationType:BITAuthenticatorIdentificationTypeDevice];
    [[BITHockeyManager sharedHockeyManager] startManager];
    [[BITHockeyManager sharedHockeyManager].authenticator authenticateInstallation];
    [[UIApplication sharedApplication] setStatusBarHidden:NO];
    
    BRCDatabaseManager *databaseManager = [BRCDatabaseManager sharedInstance];
    NSString *databaseName = @"iBurn.sqlite";
    
    [self setupFestivalDates];
    if ([databaseManager existsDatabaseWithName:databaseName]) {
        [databaseManager setupDatabaseWithName:databaseName];
    }
    else {
        BOOL copySuccesful = [databaseManager copyDatabaseFromBundle];
        [databaseManager setupDatabaseWithName:databaseName];
        if (!copySuccesful) {
            [self preloadExistingData];
        }
    }
    
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
    RIButtonItem *cancelItem = [RIButtonItem itemWithLabel:@"Dismiss"];
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil message:notification.alertBody cancelButtonItem:cancelItem otherButtonItems:nil];
    if (notification.alertAction.length > 0) {
        NSString *eventKey = [BRCEventObject localNotificationUserInfoKey];
        NSString *eventUniqueID = [notification.userInfo objectForKey:eventKey];
        dispatch_block_t actionBlock = nil;
        if (eventUniqueID) {
            actionBlock = ^{
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
            };
        }
        RIButtonItem *actionItem = [RIButtonItem itemWithLabel:notification.alertAction action:actionBlock];
        [alert addButtonItem:actionItem];
    }
    [alert show];
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

- (void)setupDefaultTabBarController
{
    self.mapViewController = [[BRCMapViewController alloc] init];
    UINavigationController *mapNavController = [[UINavigationController alloc] initWithRootViewController:self.mapViewController];
    mapNavController.tabBarItem.image = [UIImage imageNamed:@"BRCMapIcon"];
    
    self.artViewController = [[BRCFilteredTableViewController alloc] initWithViewClass:[BRCArtObject class]];
    self.artViewController.title = @"Art";
    UINavigationController *artNavController = [[UINavigationController alloc] initWithRootViewController:self.artViewController];
    artNavController.tabBarItem.image = [UIImage imageNamed:@"BRCArtIcon"];
    
    self.campsViewController = [[BRCFilteredTableViewController alloc] initWithViewClass:[BRCCampObject class]];
    self.campsViewController.title = @"Camps";
    UINavigationController *campNavController = [[UINavigationController alloc] initWithRootViewController:self.campsViewController];
    campNavController.tabBarItem.image = [UIImage imageNamed:@"BRCCampIcon"];
    
    self.eventsViewController = [[BRCEventsTableViewController alloc] initWithViewClass:[BRCEventObject class]];
    self.eventsViewController.title = @"Events";
    UINavigationController *eventsNavController = [[UINavigationController alloc] initWithRootViewController:self.eventsViewController];
    eventsNavController.tabBarItem.image = [UIImage imageNamed:@"BRCEventIcon"];
    
    self.tabBarController = [[UITabBarController alloc] init];
    self.tabBarController.viewControllers = @[mapNavController, artNavController, campNavController, eventsNavController];
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
        [BRCDataImporter loadDataFromURL:url dataClass:dataClass completionBlock:^(BOOL success, NSError *error) {
            if (!success) {
                NSLog(@"Error importing %@ data: %@", NSStringFromClass(dataClass), error);
            } else {
                NSLog(@"Imported %@ data successfully", NSStringFromClass(dataClass));
            }
        }];
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

@end
