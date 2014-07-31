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
#import "BRCLocationManager.h"

static NSString * const kBRCHasImportedDataKey = @"kBRCHasImportedDataKey";

@implementation BRCAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [[BRCDatabaseManager sharedInstance] setupDatabaseWithName:@"iBurn.sqlite"];
    
    [self preloadExistingData];
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    BRCMapViewController *mapViewController = [[BRCMapViewController alloc] init];
    UINavigationController *mapNavController = [[UINavigationController alloc] initWithRootViewController:mapViewController];
    mapNavController.tabBarItem.image = [UIImage imageNamed:@"BRCMapIcon"];
    
    BRCFilteredTableViewController *artTableVC = [[BRCFilteredTableViewController alloc] init];
    artTableVC.title = @"Art";
    artTableVC.viewClass = [BRCArtObject class];
    UINavigationController *artNavController = [[UINavigationController alloc] initWithRootViewController:artTableVC];
    artNavController.tabBarItem.image = [UIImage imageNamed:@"BRCArtIcon"];
    
    BRCFilteredTableViewController *campTableVC = [[BRCFilteredTableViewController alloc] init];
    campTableVC.title = @"Camps";
    campTableVC.viewClass = [BRCCampObject class];
    UINavigationController *campNavController = [[UINavigationController alloc] initWithRootViewController:campTableVC];
    campNavController.tabBarItem.image = [UIImage imageNamed:@"BRCCampIcon"];
    
    BRCEventsTableViewController *eventsTableVC = [[BRCEventsTableViewController alloc] init];
    eventsTableVC.title = @"Events";
    eventsTableVC.viewClass = [BRCEventObject class];
    UINavigationController *eventsNavController = [[UINavigationController alloc] initWithRootViewController:eventsTableVC];
    eventsNavController.tabBarItem.image = [UIImage imageNamed:@"BRCEventIcon"];
    
    UITabBarController *tabBarController = [[UITabBarController alloc] init];
    tabBarController.viewControllers = @[mapNavController, artNavController, campNavController, eventsNavController];
    
    [[BRCLocationManager sharedInstance] updateRecentLocation];
    
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
    NSURL *artDataURL = [[NSBundle mainBundle] URLForResource:@"art_data" withExtension:@"json"];
    NSURL *campsDataURL = [[NSBundle mainBundle] URLForResource:@"camp_data" withExtension:@"json"];
    NSURL *eventsDataURL = [[NSBundle mainBundle] URLForResource:@"event_data" withExtension:@"json"];

    NSArray *dataToLoad = @[@[artDataURL, [BRCArtObject class]],
                            @[campsDataURL, [BRCCampObject class]],
                            @[eventsDataURL, [BRCRecurringEventObject class]]];
    
    BOOL hasLoadedData = [[NSUserDefaults standardUserDefaults] boolForKey:kBRCHasImportedDataKey];
    if (hasLoadedData) {
        NSLog(@"Data already imported, skipping...");
        return;
    }
    
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

@end
