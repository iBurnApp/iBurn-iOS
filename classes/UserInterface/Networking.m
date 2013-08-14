//
//  Networking.m
//  TraiBehind
//

#import "MapViewController.h"
#import "Networking.h"
#import <Reachability.h>
#import "RMNotifications.h"


@implementation Networking
@synthesize processCount, lastWarning;

+ (Networking*)sharedInstance {
  static Networking *sharedInstance = nil;
  @synchronized(self) {
    if (sharedInstance == nil) {
			@autoreleasepool {
        sharedInstance = [[Networking alloc] init];
        [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
			}
    }
  }
  return sharedInstance;
}


- (void) reachabilityChanged: (NSNotification* )note {
	if ( [self canConnectToInternet] ) {
    [[NSNotificationCenter defaultCenter] postNotificationName:RMResumeNetworkOperations
                                                        object:self 
                                                      userInfo:nil];
    
  } else {
    [[NSNotificationCenter defaultCenter] postNotificationName:RMSuspendNetworkOperations
                                                        object:self 
                                                      userInfo:nil];		
		
  }
	
}

/**
 * Send notifications to all observers that network connection status has changed (due to 
 * toggling of Offline mode).
 */
- (void) setOfflineMode:(BOOL)value {
  if ( value ) {
    // Offline mode has been enabled.
    offlineMode = YES;
    [[NSNotificationCenter defaultCenter] postNotificationName:RMSuspendNetworkOperations
                                                        object:self 
                                                      userInfo:nil];
    
  } else {
    offlineMode = NO;
    // Offline mode has been disabled.
    [[NSNotificationCenter defaultCenter] postNotificationName:RMResumeNetworkOperations
                                                        object:self 
                                                      userInfo:nil];
  }
}

/**
 * Setting has changed. Determine if it is for offline mode and make necessary notifications.
 */
- (void) settingChanged: (NSNotification* )note {
  
  // Did the setting for offline mode change?
  NSNumber *value = [note.userInfo objectForKey:@"OFFLINE_MODE"];
	if ( value != nil ) {
    [self setOfflineMode:[value boolValue]];
  }
}

- (void) foreground {
  [reachability startNotifier];
}


- (void) background {
  [reachability stopNotifier];
}


- (void) printStatus {
  NSLog(@"current reachability status %d", [reachability currentReachabilityStatus]);
}


- (id) init { 
  self = [super init];
  reachability = [Reachability reachabilityWithHostname:@"www.google.com"];
  [reachability performSelectorOnMainThread:@selector(startNotifier) withObject:nil waitUntilDone:NO];
  // count running network processes to show/hide indicator
  processCount = 0;
  [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(reachabilityChanged:) 
                                               name: kReachabilityChangedNotification object:reachability];
  // Listen for changes in the settings. If we go in to offline mode, we need to know.
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(settingChanged:) name:@"SETTING_CHANGED" 
                                             object:nil];
  
  return self;
}


- (BOOL) canConnectToInternet {
	if ( offlineMode || [reachability currentReachabilityStatus] == 0) {
		return NO;
	}		
	return YES;
}

// check if a server can be reached, and pop a warning if not
- (BOOL) canConnectToInternetWithWarning:(NSString*)message {
	if ([reachability currentReachabilityStatus] == 0 || offlineMode) {
    int timeSince = 100;
    if (lastWarning) {
      timeSince = -[lastWarning timeIntervalSinceNow];
    }
    if (timeSince > 1) {
      lastWarning = [NSDate date];
      dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"No Internet"
                                                        message:message
                                                       delegate:nil
                                              cancelButtonTitle:@"Hide" otherButtonTitles:nil];
        [alert show];
      });
    }
		return NO;
	}
	return YES;
}


- (BOOL) connectionIs3g {
  //return YES;
  NetworkStatus status = [reachability currentReachabilityStatus];
  if(status == ReachableViaWWAN) {
    return YES;
  }
  
  return NO;
}


@end
