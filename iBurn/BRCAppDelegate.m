//
//  BRCAppDelegate.m
//  iBurn
//
//  Created by David Chiles on 7/28/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCAppDelegate.h"
#import "NSDateFormatter+iBurn.h"
#import "BRCSecrets.h"
#import "BRCEmbargo.h"
#import "NSUserDefaults+iBurn.h"
#import "CLLocationManager+iBurn.h"
#import "Appirater.h"
#import "TUSafariActivity.h"
#import <WebKit/WebKit.h>
@import TTTAttributedLabel;
#import "iBurn-Swift.h"
#import "NSUserDefaults+iBurn.h"
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

@interface BRCAppDelegate() <UNUserNotificationCenterDelegate>
@property (nonatomic, strong) CLCircularRegion *burningManRegion;

@end

@implementation BRCAppDelegate

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
        
    // Before anything touches `dependencies`: DependencyContainer wraps this manager in its
    // CoreLocationProvider at init, and the data update check below is the first access.
    self.locationManager = [CLLocationManager brc_locationManager];
    self.locationManager.delegate = self;
    // The delegate's authorization callback normally starts updates, but be explicit so a
    // relaunch with existing permission never leaves Nearby waiting on a manager that was
    // never started (the map and detail screens use their own managers).
    [self startLocationUpdatesIfAuthorized];
    
    // Bundled data lands in PlayaDB via PlayaDBSeeder (see DependencyContainer); the
    // only launch-time network work left is the PlayaDB-native OTA check, which
    // throttles itself to once a day and imports straight into PlayaDB.
    if ([NSUserDefaults areDownloadsDisabled]) {
        NSLog(@"Downloads are disabled, skipping update check.");
    } else {
        [self checkForDataUpdates];
    }
    
    // Launch URLs / universal links arrive in the scene's connection options now
    // (SceneDelegate), and a notification tap that launches the app still reaches
    // userNotificationCenter:didReceiveNotificationResponse: below.
    
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
    
    [LocationStorage setup:nil];
    
    // The window, root view controller and onboarding are created by SceneDelegate
    // (UIApplicationSceneManifest in iBurn-Info.plist).
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
    
    [[UIApplication sharedApplication] brc_presentOnFrontmostViewController:alert];
}

// applicationDidBecomeActive: (and the other foreground/background callbacks) are not
// called under the UIScene lifecycle; SceneDelegate.sceneDidBecomeActive: calls
// startLocationUpdatesIfAuthorized instead. The UIApplication state notifications still post.

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    DDLogInfo(@"applicationWillTerminate");
}

- (void) applicationDidReceiveMemoryWarning:(UIApplication *)application {
    DDLogWarn(@"applicationDidReceiveMemoryWarning:");
}

- (void) setupRegionBasedUnlock {
    NSParameterAssert(self.locationManager != nil);
    self.burningManRegion = [BRCLocations burningManRegion];
}

- (void) enteredBurningManRegion {
    // Being here is the un-forgeable half of the embargo rule, so it latches. It
    // unlocks nothing by itself — the tier's date still has to arrive — which is
    // why this can fire harmlessly weeks before the event.
    BOOL campWasVisible = [BRCEmbargo canShowCampLocations];
    BOOL artWasVisible = [BRCEmbargo canShowArtLocations];
    BOOL alreadyLatched = BRCEmbargoService.hasSeenBurningManRegion;
    [BRCEmbargoService noteEnteredBurningManRegion];
    BOOL didUnlock = ([BRCEmbargo canShowCampLocations] != campWasVisible)
        || ([BRCEmbargo canShowArtLocations] != artWasVisible);
    if (!didUnlock) {
        return;
    }
    // Something just became visible: tell the live observations (map annotations,
    // SwiftUI rows) so they don't wait for a relaunch.
    [BRCEmbargoNotifier postDidClear];
    if (!alreadyLatched) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Data Unlocked" message:@"Looks like you're at Burning Man! The restricted data is now unlocked." preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"Sweet!" style:UIAlertActionStyleCancel handler:nil];
        [alert addAction:cancel];
        [[UIApplication sharedApplication] brc_presentOnFrontmostViewController:alert];
    }
}

+ (BRCAppDelegate*) shared {
    return (BRCAppDelegate*)[UIApplication sharedApplication].delegate;
}

- (void) startLocationUpdatesIfAuthorized {
    CLAuthorizationStatus status = self.locationManager.authorizationStatus;
    if (status == kCLAuthorizationStatusAuthorizedWhenInUse || status == kCLAuthorizationStatusAuthorizedAlways) {
        [self.locationManager startUpdatingLocation];
    }
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
        [[UIApplication sharedApplication] brc_presentOnFrontmostViewController:alert];
    }
}

- (void) locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
    CLLocation *lastLocation = [locations lastObject];
    if ([self.burningManRegion containsCoordinate:lastLocation.coordinate]) {
        [self enteredBurningManRegion];
    }
    // Breadcrumb tracking is handled by LocationStorage (GRDB-backed)
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
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self checkForDataUpdatesWithCompletion:^(BOOL didImport) {
            [task setTaskCompletedWithSuccess:didImport];
        }];
    });
}

// Deep links (application:openURL:options: / continueUserActivity:) moved to SceneDelegate:
// UIKit delivers them to the scene once scenes are adopted.

@end
