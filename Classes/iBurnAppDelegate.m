//
//  iBurnAppDelegate.m
//  iBurn
//
//  Created by Jeffrey Johnson on 2009-01-11.
//  Copyright Burning Man Earth 2009. All rights reserved.
//

#import "iBurnAppDelegate.h"
#import "MapViewController.h"
#import "CampTableViewController.h"
#import "ArtTableViewController.h"
#import "TweetTableViewController.h"
#import "MessageTableViewController.h"
#import "EventTableViewController.h"
#import "NewsViewController.h"
#import "SyncViewController.h"
#import "SettingsTableViewController.h"
#import "PeopleTableViewController.h"
#import "CarsTableViewController.h"
#import "FavoritesTableViewController.h"
#import "ThemeCamp.h"
//#import "SQLiteInstanceManager.h"
#import "OAuthConsumer.h"
#import "MapDownloader.h"
#import "BurnTileSource.h"
#import "Reachability.h"
#import "ArtNodeController.h"
#import "EventNodeController.h"
#import "RotatingTabBarController.h"
#import "SortableTable.h"
#import <CommonCrypto/CommonDigest.h>
#import "UnlockViewController.h"
#import "ASIHTTPRequest.h"

//#import <JSON/JSON.h>
//#import <JSON/SBJSON.h>

@implementation iBurnAppDelegate

@synthesize window, themeCamps, launchDefault, campNodeController, artNodeController, eventNodeController, tabBarController, embargoed;


- (NSString*) documentsDirectory {
  NSArray *documentPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  return [documentPaths objectAtIndex:0];
}

- (void) checkOrCreateDatabase {
	//See if the CoreData database is populated.  If not populate it from the API.
	NSFetchRequest *testRequest = [[NSFetchRequest alloc] init];
	[testRequest setEntity:[NSEntityDescription entityForName:@"ThemeCamp" inManagedObjectContext:[self managedObjectContext]]];
	NSError *error;
	NSInteger dbCount = [[self managedObjectContext] countForFetchRequest:testRequest error:&error];
  //NSLog(@"DBCount: %i", dbCount);
}


- (void) initControllers {
	self.embargoed = YES;

  NSMutableArray *controllers = [[[NSMutableArray alloc] init]autorelease];
  NSArray *classes = [NSArray arrayWithObjects:
                      [MapViewController class], 
                      [ArtTableViewController class],
                      [CampTableViewController class],
                      [EventTableViewController class],
                      [UnlockViewController class],
                      //[PeopleTableViewController class],
                      //[TweetTableViewController class],
                      //[MessageTableViewController class],
                      //[FavoritesTableViewController class],
                      //[SettingsTableViewController class],
                      //[NewsViewController class],
                      //[SyncViewController class],
                      nil];
  NSArray *titles = [NSArray arrayWithObjects:@"Map",@"",@"",@"",@"",nil];
  //,@"",@"",@"",@"",@"",@"",@"",@"",
  int i = 0;
  id viewController;
  for (NSString *title in titles) {
    Class vcClass = [classes objectAtIndex:i];
    if ([title isEqualToString:@""]) {
      viewController = [[[vcClass alloc]init]autorelease];
    } else {
      viewController = [[[vcClass alloc]initWithTitle:title]autorelease];
    }
    UINavigationController *nav = [[[UINavigationController alloc]initWithRootViewController:viewController]autorelease];  
    nav.navigationBar.barStyle = UIBarStyleBlack;
    [controllers addObject:nav];
    i++;
  }
  
  tabBarController = [[RotatingTabBarController alloc] init];
  tabBarController.viewControllers = controllers;
  tabBarController.delegate = self;
  //[self testOAuthAccessProtected];
  [window addSubview:tabBarController.view];
  [window makeKeyAndVisible];
  //[self performSelector:@selector(downloadMaps) withObject:nil afterDelay:5];
  
  self.artNodeController = [[[ArtNodeController alloc]init]autorelease];
  self.artNodeController.delegate = (ArtTableViewController*)[[tabBarController.viewControllers objectAtIndex:1]visibleViewController];
  self.campNodeController = [[[CampNodeController alloc]init]autorelease];
  self.campNodeController.delegate = (CampTableViewController*)[[tabBarController.viewControllers objectAtIndex:2]visibleViewController];
  self.eventNodeController = [[[EventNodeController alloc]init]autorelease];
  self.eventNodeController.delegate = (EventTableViewController*)[[tabBarController.viewControllers objectAtIndex:3]visibleViewController];
  //[self checkOrCreateDatabase];
  [campNodeController getNodes];
  [artNodeController getNodes];
  [eventNodeController getNodes];
}  

- (void)applicationDidFinishLaunching:(UIApplication *)application {
	launchDefault = YES;
  [self initControllers];
	[self performSelector:@selector(postLaunch) withObject:nil afterDelay:0.1];
}


- (void) downloadMaps {
  [self downloadMaps:NO];
}


- (void) downloadMaps:(BOOL) refreshTiles {
  // Check internet connection
  BurnTileSource *bts = [[[BurnTileSource alloc] init] autorelease];
  if (![self canConnectToInternet]) {
    NSFileManager *NSFm= [NSFileManager defaultManager]; 
    
    // if no internet and thet tiles arent cached, show an alert
    if(![NSFm fileExistsAtPath:[bts tileDirectory] isDirectory:nil] || refreshTiles) {
      UIAlertView *alert = [[UIAlertView alloc] 
                            initWithTitle: @"No Internet Connection" 
                            message:@"Please start iBurn while connected to the internet to download playa data"
                            delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
      [alert show];
      [alert release];
      return;
    }
  }
  
  MapViewController *mapViewController = (MapViewController*)[[tabBarController.viewControllers objectAtIndex:0]visibleViewController];
  MapDownloader* dl = [[MapDownloader alloc] initWithTileSource:bts progressView:mapViewController.progressView];
  [self setViewForDownloading];
  dl.refreshTiles = refreshTiles;
  [NSThread detachNewThreadSelector:@selector(startMapDownload) toTarget:dl withObject:nil];
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
  //reachability = [[Reachability reachabilityWithHostName:@"earthdev.burningman.com"] retain];
  reachability = [[Reachability reachabilityWithHostName:@"www.gaiagps.com"] retain];
  
	[reachability startNotifier];
  [self canConnectToInternet];
  // count running network processes to show/hide indicator
  [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(reachabilityChanged:) 
                                               name: kReachabilityChangedNotification object:reachability];
  //[self initializeOAuthConsumer];
  [self performSelector:@selector(checkEmbargo) withObject:nil afterDelay:2];
}

/*- (void) requestDone {
 //[[[tabBarController.viewControllers objectAtIndex:0]visibleViewController] showMarkersOnScreen];  
 [(CampTableViewController*)[[tabBarController.viewControllers objectAtIndex:2]visibleViewController]reloadTable];
 }*/


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
  if ([MyCLController sharedInstance].locationManager.locationServicesEnabled ) {
    [[MyCLController sharedInstance].locationManager startUpdatingLocation];
  }
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
  if ([MyCLController sharedInstance].locationManager.locationServicesEnabled ) {
    [[MyCLController sharedInstance].locationManager stopUpdatingLocation];
  }
}

- (void) checkAndCreateDatabase {
  NSString* defaultDBName =  @"iBurn.sqlite";
  

  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSString* dbPath = [[self applicationDocumentsDirectory] stringByAppendingPathComponent: @"iBurn2011.sqlite"];
  BOOL success = [fileManager fileExistsAtPath:dbPath];
  
  // If the database already exists then return without doing anything
  if(success) return;
  
  // Get the path to the database in the application package
  NSString *databasePathFromApp = [[[NSBundle mainBundle] resourcePath]
                                   stringByAppendingPathComponent:defaultDBName];
  
  // Copy the database from the package to the users filesystem  
  [fileManager copyItemAtPath:databasePathFromApp toPath:dbPath
                        error:nil];
}



- (NSPersistentStoreCoordinator *) createPersistentStoreCoordinator {
	//[self checkAndCreateDatabase];
	NSURL *storeURL = [NSURL fileURLWithPath: [[self applicationDocumentsDirectory] stringByAppendingPathComponent: @"iBurn2011.sqlite"]];
	
	NSError *error = nil;
	NSPersistentStoreCoordinator* psc = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
	if (![psc addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&error]) {
		/*
		 Replace this implementation with code to handle the error appropriately.
		 
		 abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. If it is not possible to recover from the error, display an alert panel that instructs the user to quit the application by pressing the Home button.
		 
		 Typical reasons for an error here include:
		 * The persistent store is not accessible;
		 * The schema for the persistent store is incompatible with current managed object model.
		 Check the error message to determine what the actual problem was.
		 
		 
		 If the persistent store is not accessible, there is typically something wrong with the file path. Often, a file URL is pointing into the application's resources directory instead of a writeable directory.
		 
		 If you encounter schema incompatibility errors during development, you can reduce their frequency by:
		 * Simply deleting the existing store:
		 [[NSFileManager defaultManager] removeItemAtURL:storeURL error:nil]
		 
		 * Performing automatic lightweight migration by passing the following dictionary as the options parameter: 
		 [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES],NSMigratePersistentStoresAutomaticallyOption, [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption, nil];
		 
		 Lightweight migration will only work for a limited set of schema changes; consult "Core Data Model Versioning and Data Migration Programming Guide" for details.
		 
		 */
		NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
		abort();
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
  self.embargoed = NO;
  [[NSNotificationCenter defaultCenter] postNotificationName:@"LIFT_EMBARGO" object:nil];
}

- (NSString*) passwordFile {
  return [NSString stringWithFormat:@"%@/password", [self applicationDocumentsDirectory]];
  
}

#define CORRECT_HASH  @"38EBE77897EC9D73675BC8182DA7F75D"

- (BOOL) checkPassword:(NSString*) password {
  //if ([iBurnAppDelegate md5:password] isEqualToString:@"blah
  NSLog(@"mdf password %@", [iBurnAppDelegate md5:password]);
  NSString* hash = [iBurnAppDelegate md5:password];
  if ([hash isEqualToString:CORRECT_HASH]) {
    [password writeToFile:[self passwordFile] atomically:YES];
    [self liftEmbargo];
    return YES;
  }
  return NO;
}

- (NSString*) getStoredPassword {
  if ([[NSFileManager defaultManager] fileExistsAtPath:[self passwordFile]]) {
    NSString * password = [NSString stringWithContentsOfFile:[self passwordFile]];
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
    NSString * password = [NSString stringWithContentsOfFile:[self passwordFile]];
    [self checkPassword:password];
    return;
  }
  
  [[NSNotificationCenter defaultCenter] removeObserver:self name:kReachabilityChangedNotification object:nil];
  
  if ([self canConnectToInternet]) {
    NSURL *url = [NSURL URLWithString:@"http://www.gaiagps.com/iburn/embargo"];
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


- (void)dealloc {
	[managedObjectContext_ release];
	[managedObjectModel_ release];
	[persistentStoreCoordinator_ release];	
	[tabBarController release];
  [window release];
  [campNodeController release];
  [artNodeController release];
  [eventNodeController release];
  [super dealloc];
}


@end
