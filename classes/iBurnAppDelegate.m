//
//  iBurnAppDelegate.m
//  iBurn
//
//  Created by Jeffrey Johnson on 2009-01-11.
//  Copyright Burning Man Earth 2009. All rights reserved.
//

#import "ArtNodeController.h"
#import "ArtTableViewController.h"
#import <ASIHTTPRequest.h>
#import "CampTableViewController.h"
#import "EventNodeController.h"
#import "EventTableViewController.h"
#import "iBurnAppDelegate.h"
#import "MapViewController.h"
#import <Reachability.h>
#import "RotatingTabBarController.h"
#import "ThemeCamp.h"
#import "UnlockViewController.h"
#import "util.h"


#define DATABASE_NAME @"iBurn2013.sqlite"

@implementation iBurnAppDelegate

@synthesize window, themeCamps, launchDefault, campNodeController, artNodeController, eventNodeController, tabBarController, embargoed, bgMoc;


- (NSString*) documentsDirectory {
  NSArray *documentPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  return [documentPaths objectAtIndex:0];
}

static NSMutableDictionary * timerDict = nil;

void startTimer(NSString* name) {
  if (!timerDict) {
    timerDict = [NSMutableDictionary dictionary];
  }
  [timerDict setObject:[NSDate date] forKey:name];
  
}

void printTimer(NSString* name) {
  NSDate * startTime = (NSDate*) [timerDict objectForKey:name];
  NSLog(@"%@ time %f", name, -[startTime timeIntervalSinceNow]);
}

- (void) closeDatabaseCompletely {
  
}


- (void) checkOrCreateDatabase {
	//See if the CoreData database is populated.  If not populate it from the API.
	NSFetchRequest *testRequest = [[NSFetchRequest alloc] init];
	[testRequest setEntity:[NSEntityDescription entityForName:@"ThemeCamp" inManagedObjectContext:[self managedObjectContext]]];
	NSError *error = nil;
	NSInteger dbCount = [[self managedObjectContext] countForFetchRequest:testRequest error:&error];
  if (error) {
    NSLog(@"DB Error: %@ %@, DBCount: %i", [error localizedDescription], [error userInfo], dbCount);
  }
  
  if (dbCount < 100) {
    [self reloadData];
  }

}

- (void) reloadData {
  startTimer(@"parsingJson");
  [self.campNodeController importDataFromFile:@"camp_data_and_locations_ids"];
  [self.managedObjectContext reset];
  printTimer(@"parsingJson");
  [self.eventNodeController importDataFromFile:@"event_data_and_locations"];
  [self.managedObjectContext reset];
  printTimer(@"parsingJson");
  [self.artNodeController importDataFromFile:@"art_data_and_locations"];
  [self.managedObjectContext reset];
  printTimer(@"parsingJson");
}

- (void) initNodeControllers {
  self.artNodeController = [[ArtNodeController alloc]init];
  self.campNodeController = [[CampNodeController alloc]init];
  self.eventNodeController = [[EventNodeController alloc]init];

}

- (void) initControllers {
	self.embargoed = YES;

  NSMutableArray *controllers = [[NSMutableArray alloc] init];
  NSArray *classes = [NSArray arrayWithObjects:
                      [MapViewController class], 
                      [ArtTableViewController class],
                      [CampTableViewController class],
                      [EventTableViewController class],
                      [UnlockViewController class],
                      nil];
  NSArray *titles = [NSArray arrayWithObjects:@"Map",@"",@"",@"",@"",nil];
  int i = 0;
  id viewController;
  for (NSString *title in titles) {
    Class vcClass = [classes objectAtIndex:i];
    if ([title isEqualToString:@""]) {
      viewController = [[vcClass alloc]init];
    } else {
      viewController = [[vcClass alloc]initWithTitle:title];
    }
    UINavigationController *nav = [[UINavigationController alloc]initWithRootViewController:viewController];
    nav.navigationBar.barStyle = UIBarStyleBlack;
    [controllers addObject:nav];
    i++;
  }
  
  tabBarController = [[RotatingTabBarController alloc] init];
  tabBarController.viewControllers = controllers;
  tabBarController.delegate = self;
  //[self testOAuthAccessProtected];
  window.rootViewController = tabBarController;
  
  self.artNodeController.delegate = (ArtTableViewController*)[[tabBarController.viewControllers objectAtIndex:1]visibleViewController];
  self.campNodeController.delegate = (CampTableViewController*)[[tabBarController.viewControllers objectAtIndex:2]visibleViewController];
  self.eventNodeController.delegate = (EventTableViewController*)[[tabBarController.viewControllers objectAtIndex:3]visibleViewController];
  
  if ([CLLocationManager locationServicesEnabled]) {
    [[MyCLController sharedInstance].locationManager startUpdatingLocation];
  }

}  

- (void)applicationDidFinishLaunching:(UIApplication *)application {
	launchDefault = YES;
  NSString *path = [self unlockedFile];
  if ([[NSFileManager defaultManager]fileExistsAtPath:path]) {
    [self liftEmbargo];
  }
  [self initControllers];
  [window makeKeyAndVisible];

  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_current_queue(), ^{
    [self initNodeControllers];
    [self managedObjectContext];
    [self checkOrCreateDatabase];
    [self postLaunch];
  });
  
}


- (void) reachabilityChanged: (NSNotification* )note {
  if ([reachability currentReachabilityStatus] != 0) {
    // put actions when lose internet connection here    
  }
}


- (BOOL) canConnectToInternet {
  return [reachability currentReachabilityStatus] != 0;
}


- (void)postLaunch {
	if (!launchDefault) return;
  reachability = [Reachability reachabilityWithHostname:@"www.google.com"];
  
	[reachability startNotifier];
  [self canConnectToInternet];
  // count running network processes to show/hide indicator
  [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(reachabilityChanged:) 
                                               name: kReachabilityChangedNotification object:reachability];
  [self performSelector:@selector(checkEmbargo) withObject:nil afterDelay:2];
}


- (void) requestDone {
 //[[[tabBarController.viewControllers objectAtIndex:0]visibleViewController] showMarkersOnScreen];  
 //[(CampTableViewController*)[[tabBarController.viewControllers objectAtIndex:2]visibleViewController]reloadTable];
}


- (void) setViewForDownloading {
  MapViewController *mapViewController = (MapViewController*)[[tabBarController.viewControllers objectAtIndex:0]visibleViewController];
  [mapViewController.progressView setProgress:0.01];
  [mapViewController.progressView setAlpha:1];
}


- (void) dismissProgessIndicator {	
  [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
  MapViewController *mapViewController = (MapViewController*)[[[tabBarController.viewControllers objectAtIndex:0]viewControllers]objectAtIndex:0];
 	[mapViewController.progressView setAlpha:0];
}


#pragma mark -
#pragma mark Core Data stack

/**
 Returns the managed object context for the application.
 If the context doesn't already exist, it is created and bound to the persistent store coordinator for the application.
 */
- (NSManagedObjectContext *)managedObjectContext {
	
	if (managedObjectContext_ != nil) {
		return managedObjectContext_;
	}
	
	NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
	if (coordinator != nil) {
		managedObjectContext_ = [[NSManagedObjectContext alloc] init];
		[managedObjectContext_ setPersistentStoreCoordinator:coordinator];
	}
	return managedObjectContext_;
}


/**
 Returns the managed object model for the application.
 If the model doesn't already exist, it is created from the application's model.
 */
- (NSManagedObjectModel *)managedObjectModel {
	
	if (managedObjectModel_ != nil) {
		return managedObjectModel_;
	}
	NSString *modelPath = [[NSBundle mainBundle] pathForResource:@"iBurn" ofType:@"mom"];
	NSLog(@"modelPath: %@", modelPath);
	NSURL *modelURL = [NSURL fileURLWithPath:modelPath];
	managedObjectModel_ = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];    
	return managedObjectModel_;
}


/**
 Returns the persistent store coordinator for the application.
 If the coordinator doesn't already exist, it is created and the application's store added to it.
 */
- (NSPersistentStoreCoordinator *) persistentStoreCoordinator {
	
	if (persistentStoreCoordinator_ != nil) {
		return persistentStoreCoordinator_;
	}
  persistentStoreCoordinator_ = [self createPersistentStoreCoordinator];
  return persistentStoreCoordinator_;
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
  [self checkEmbargo];
  if ([CLLocationManager locationServicesEnabled] ) {
    [[MyCLController sharedInstance].locationManager startUpdatingLocation];
  }
  if([CLLocationManager headingAvailable])
  {
    [[MyCLController sharedInstance].locationManager startUpdatingHeading];
  }
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
  if ([CLLocationManager locationServicesEnabled] ) {
    [[MyCLController sharedInstance].locationManager stopUpdatingLocation];
  }
  if([CLLocationManager headingAvailable])
  {
    [[MyCLController sharedInstance].locationManager stopUpdatingHeading];
  }
}





- (NSPersistentStoreCoordinator *) createPersistentStoreCoordinator {
  NSString* dbPath = [privateDocumentsDirectory() stringByAppendingPathComponent: DATABASE_NAME];
  BOOL success = [[NSFileManager defaultManager] fileExistsAtPath:dbPath];
  
  
  if (![[NSFileManager defaultManager] fileExistsAtPath:dbPath]) {
    NSString *databasePathFromApp = [[[NSBundle mainBundle] resourcePath]
                                     stringByAppendingPathComponent:DATABASE_NAME];
    
    NSError* error = nil;
    [[NSFileManager defaultManager] copyItemAtPath:databasePathFromApp toPath:dbPath
                          error:&error];
  }
	NSURL *storeURL = [NSURL fileURLWithPath: [privateDocumentsDirectory() stringByAppendingPathComponent: DATABASE_NAME]];
	
	NSError *error = nil;
	NSPersistentStoreCoordinator* psc = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
	if (![psc addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&error]) {
    NSLog(@"Unresolved error %@, %@", error, [error userInfo]);

    [[NSFileManager defaultManager] removeItemAtPath:dbPath error:nil];
    return [self createPersistentStoreCoordinator];
	}    
  
	return psc;
}

#pragma mark - enforce embargo

+ (NSString *) md5:(NSString *)str {
  const char *cStr = [str UTF8String];
  unsigned char result[16];
  CC_MD5( cStr, strlen(cStr), result );
  return [NSString stringWithFormat:
          @"%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X",
          result[0], result[1], result[2], result[3], 
          result[4], result[5], result[6], result[7],
          result[8], result[9], result[10], result[11],
          result[12], result[13], result[14], result[15]
          ]; 
}

- (void) liftEmbargo {
  if (!self.embargoed) {
    return;
  }
  self.embargoed = NO;
  NSError *error;
  BOOL succeed = [@"unlocked" writeToFile:[self unlockedFile]
                            atomically:YES encoding:NSUTF8StringEncoding error:&error];
  if (!succeed){
    // Handle error here
  }
  
  [[NSNotificationCenter defaultCenter] postNotificationName:@"LIFT_EMBARGO" object:nil];
}

- (NSString*) passwordFile {
  return [NSString stringWithFormat:@"%@/password2013", [self applicationDocumentsDirectory]];
  
}

- (NSString*) unlockedFile {
  return [NSString stringWithFormat:@"%@/unlocked2013", [self applicationDocumentsDirectory]];
  
}

#define CORRECT_HASH  @"59D59BD0A95DB884EC0442C80411D52D"

- (BOOL) checkPassword:(NSString*) password {
  //if ([iBurnAppDelegate md5:password] isEqualToString:@"blah
  password = [password lowercaseString];
  NSLog(@"mdf password %@", [iBurnAppDelegate md5:password]);
  NSString* hash = [iBurnAppDelegate md5:password];
  if ([hash isEqualToString:CORRECT_HASH]) {
    [password writeToFile:[self passwordFile] atomically:YES encoding:NSUTF8StringEncoding error:nil];
    [self liftEmbargo];
    return YES;
  }
  return NO;
}

- (NSString*) getStoredPassword {
  if ([[NSFileManager defaultManager] fileExistsAtPath:[self passwordFile]]) {
    NSString * password = [NSString stringWithContentsOfFile:[self passwordFile] encoding:NSUTF8StringEncoding error:nil];
    return password;
  }
  return nil;
}
- (void)requestDone:(ASIHTTPRequest *)request {
  NSString *response = [request responseString];
  [self checkPassword:response];
}


- (void)requestWentWrong:(ASIHTTPRequest *)request {
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(checkEmbargo) name:kReachabilityChangedNotification object:reachability];
}


- (void) checkEmbargo {
  NSLog(@"%@", [self passwordFile]);

  if ([[NSFileManager defaultManager] fileExistsAtPath:[self passwordFile]]) {
    NSString * password = [NSString stringWithContentsOfFile:[self passwordFile] encoding:NSUTF8StringEncoding error:nil];
    
    [self checkPassword:password];
    return;
  }
  
  [[NSNotificationCenter defaultCenter] removeObserver:self name:kReachabilityChangedNotification object:nil];
  
  if ([self canConnectToInternet]) {
    NSURL *url = [NSURL URLWithString:@"http://www.gaiagps.com/iburn/embargo2013"];
    ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:url];
    [request setDidFinishSelector:@selector(requestDone:)];
		[request setDidFailSelector:@selector(requestWentWrong:)];
    [request setDelegate:self];
    [request startAsynchronous];
     
  } else {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(checkEmbargo) name:kReachabilityChangedNotification object:reachability];  
  }
}



#pragma mark -
#pragma mark Application's Documents directory

/**
 Returns the path to the application's Documents directory.
 */
- (NSString *)applicationDocumentsDirectory {
	return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
}


@end
