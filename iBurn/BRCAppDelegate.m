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

static NSString * const kBRCHasImportedDataKey = @"kBRCHasImportedDataKey";

@implementation BRCAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [[BITHockeyManager sharedHockeyManager] configureWithBetaIdentifier:kBRCHockeyBetaIdentifier
                                                         liveIdentifier:kBRCHockeyLiveIdentifier delegate:self];
    [[BITHockeyManager sharedHockeyManager].authenticator setIdentificationType:BITAuthenticatorIdentificationTypeDevice];
    [[BITHockeyManager sharedHockeyManager] startManager];
    [[BITHockeyManager sharedHockeyManager].authenticator authenticateInstallation];
    
    [[BRCDatabaseManager sharedInstance] setupDatabaseWithName:@"iBurn.sqlite"];
    
    [self preloadExistingData];
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    BRCMapViewController *mapViewController = [[BRCMapViewController alloc] init];
    UINavigationController *mapNavController = [[UINavigationController alloc] initWithRootViewController:mapViewController];
    mapNavController.tabBarItem.image = [UIImage imageNamed:@"BRCMapIcon"];
    
    BRCFilteredTableViewController *artTableVC = [[BRCFilteredTableViewController alloc] initWithViewClass:[BRCArtObject class]];
    artTableVC.title = @"Art";
    UINavigationController *artNavController = [[UINavigationController alloc] initWithRootViewController:artTableVC];
    artNavController.tabBarItem.image = [UIImage imageNamed:@"BRCArtIcon"];
    
    BRCFilteredTableViewController *campTableVC = [[BRCFilteredTableViewController alloc] initWithViewClass:[BRCCampObject class]];
    campTableVC.title = @"Camps";
    UINavigationController *campNavController = [[UINavigationController alloc] initWithRootViewController:campTableVC];
    campNavController.tabBarItem.image = [UIImage imageNamed:@"BRCCampIcon"];
    
    BRCEventsTableViewController *eventsTableVC = [[BRCEventsTableViewController alloc] initWithViewClass:[BRCEventObject class]];
    eventsTableVC.title = @"Events";
    UINavigationController *eventsNavController = [[UINavigationController alloc] initWithRootViewController:eventsTableVC];
    eventsNavController.tabBarItem.image = [UIImage imageNamed:@"BRCEventIcon"];
    
    UITabBarController *tabBarController = [[UITabBarController alloc] init];
    tabBarController.viewControllers = @[mapNavController, artNavController, campNavController, eventsNavController];
    
    self.window.backgroundColor = [UIColor whiteColor];
    self.window.rootViewController = tabBarController;
    
    [self.window makeKeyAndVisible];
    return YES;
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

- (void) preloadExistingData {
    NSURL *artDataURL = [[NSBundle mainBundle] URLForResource:@"art" withExtension:@"json"];
    NSURL *campsDataURL = [[NSBundle mainBundle] URLForResource:@"camps" withExtension:@"json"];
    NSURL *eventsDataURL = [[NSBundle mainBundle] URLForResource:@"events" withExtension:@"json"];
    NSURL *datesInfoURL = [[NSBundle mainBundle] URLForResource:@"dates_info" withExtension:@"json"];

    NSArray *dataToLoad = @[@[artDataURL, [BRCArtObject class]],
                            @[campsDataURL, [BRCCampObject class]],
                            @[eventsDataURL, [BRCRecurringEventObject class]]];
    
    BOOL hasLoadedData = [[NSUserDefaults standardUserDefaults] boolForKey:kBRCHasImportedDataKey];
    if (hasLoadedData) {
        NSLog(@"Data already imported, skipping...");
        return;
    }
    
    NSData *datesInfoData = [NSData dataWithContentsOfURL:datesInfoURL];
    NSDictionary *datesInfoDictionary = [NSJSONSerialization JSONObjectWithData:datesInfoData options:0 error:nil];
    
    NSDictionary *rangeInfoDictionary = [datesInfoDictionary objectForKey:@"rangeInfo"];
    NSString *startDateString = [rangeInfoDictionary objectForKey:@"startDate"];
    NSDate *startDate = [[NSDateFormatter brc_threadSafeDateFormatter] dateFromString:startDateString];
    NSString *endDateString = [rangeInfoDictionary objectForKey:@"endDate"];
    NSDate *endDate = [[NSDateFormatter brc_threadSafeDateFormatter] dateFromString:endDateString];
    NSArray *majorEventsArray = [datesInfoDictionary objectForKey:@"majorEvents"];
    
    [[NSUserDefaults standardUserDefaults] setObject:majorEventsArray forKey:kBRCMajorEventsKey];
    [[NSUserDefaults standardUserDefaults] setObject:startDate forKey:kBRCStartDateKey];
    [[NSUserDefaults standardUserDefaults] setObject:endDate forKey:kBRCEndDateKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [dataToLoad enumerateObjectsUsingBlock:^(NSArray *obj, NSUInteger idx, BOOL *stop) {
        NSURL *url = [obj firstObject];
        Class dataClass = [obj lastObject];
        [BRCDataImporter loadDataFromURL:url dataClass:dataClass completionBlock:^(BOOL success, NSError *error) {
            if (!success) {
                NSLog(@"Error importing %@ data: %@", NSStringFromClass(dataClass), error);
            } else {
                NSLog(@"Imported %@ data successfully", NSStringFromClass(dataClass));
                [[NSUserDefaults standardUserDefaults] setObject:@YES forKey:kBRCHasImportedDataKey];
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

@end
