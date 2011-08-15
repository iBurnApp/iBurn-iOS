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

//#import <JSON/JSON.h>
//#import <JSON/SBJSON.h>

@implementation iBurnAppDelegate

@synthesize window, themeCamps, launchDefault, campNodeController, artNodeController, eventNodeController, tabBarController;


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
  NSMutableArray *controllers = [[[NSMutableArray alloc] init]autorelease];
  NSArray *classes = [NSArray arrayWithObjects:
                      [MapViewController class], 
                      [ArtTableViewController class],
                      [CampTableViewController class],
                      [EventTableViewController class],
                      //[CarsTableViewController class],
                      //[PeopleTableViewController class],
                      //[TweetTableViewController class],
                      //[MessageTableViewController class],
                      [FavoritesTableViewController class],
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
    nav.navigationBar.tintColor = [UIColor blackColor];
    [controllers addObject:nav];
    i++;
  }
  
  tabBarController = [[RotatingTabBarController alloc] init];
  tabBarController.viewControllers = controllers;
  tabBarController.delegate = self;
  //[self testOAuthAccessProtected];
  [window addSubview:tabBarController.view];
  [window makeKeyAndVisible];
  [self performSelector:@selector(downloadMaps) withObject:nil afterDelay:5];
  
  self.artNodeController = [[[ArtNodeController alloc]init]autorelease];
  self.artNodeController.delegate = (ArtTableViewController*)[[tabBarController.viewControllers objectAtIndex:1]visibleViewController];
  self.campNodeController = [[[CampNodeController alloc]init]autorelease];
  self.campNodeController.delegate = (CampTableViewController*)[[tabBarController.viewControllers objectAtIndex:2]visibleViewController];
  self.eventNodeController = [[[EventNodeController alloc]init]autorelease];
  self.eventNodeController.delegate = (EventTableViewController*)[[tabBarController.viewControllers objectAtIndex:3]visibleViewController];
  [self checkOrCreateDatabase];
  [campNodeController getNodes];
  [artNodeController getNodes];
  [eventNodeController getNodes];
}  

- (void)applicationDidFinishLaunching:(UIApplication *)application {
	launchDefault = YES;
  [self initControllers];
	[self performSelector:@selector(postLaunch) withObject:nil afterDelay:0.0];
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
  reachability = [[Reachability reachabilityWithHostName:@"earthdev.burningman.com"] retain];
  [reachability startNotifier];
  [self canConnectToInternet];
  // count running network processes to show/hide indicator
  [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(reachabilityChanged:) 
                                               name: kReachabilityChangedNotification object:reachability];
  //[self initializeOAuthConsumer];
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
  MapViewController *mapViewController = (MapViewController*)[[tabBarController.viewControllers objectAtIndex:0]visibleViewController];
 	[mapViewController.progressView setAlpha:0];
}


- (void)initializeOAuthConsumer {
	//ByNotes
	//OAConsumer *consumer = [[OAConsumer alloc] initWithKey:@"yw1yag90ptqy290qp1qkcrqo0th4vco8" secret:@"p0syik010vu56migwh8wrcg4vy1ckco1"];
	//FireEagle
	//OAConsumer *consumer = [[OAConsumer alloc] initWithKey:@"DCMIA8IT4S1I" secret:@"sWBXgywgtsjhz7C7oMQBBsLHPXOVmJcg"];
	//Mobitag
	//OAConsumer *consumer = [[OAConsumer alloc] initWithKey:@"60vnbtmjffa0jcoel9tfc0jmlcc8lrnp" secret:@"10e7cer098glrzwysogwhajne7rafkrv"];
	OAConsumer *consumer = [[OAConsumer alloc] initWithKey:@"key" secret:@"secret"];	
	accessToken = [[OAToken alloc] initWithUserDefaultsUsingServiceProviderName:@"mobitag.pictearth.com" prefix:@"MobitagAccess"];
	NSLog(@"accessToken initializeOAuthConsumer = %@", accessToken);
	if(accessToken == NULL) {
		//NSURL *requestTokenURL = [NSURL URLWithString:@"https://fireeagle.yahooapis.com/oauth/request_token"];
		//NSURL *requestTokenURL = [NSURL URLWithString:@"http://mobitag.pictearthusa.com/api/1.0/oauth/request_token"];
		NSURL *requestTokenURL = [NSURL URLWithString:@"http://localhost:8000/oauth/request_token"];
		//NSURL *requestTokenURL = [NSURL URLWithString:@"http://bynotes.com/api/1.0/oauth/request_token"];
		OAMutableURLRequest *request = [[OAMutableURLRequest alloc] initWithURL:requestTokenURL
                                                                   consumer:consumer
                                                                      token:nil   // we don't have a Token yet
                                                                      realm:nil   // our service provider doesn't specify a realm
                                                          signatureProvider:[[OAPlaintextSignatureProvider alloc] init]]; // use the default method, HMAC-SHA1
		
		[request setHTTPMethod:@"GET"];
		OADataFetcher *fetcher = [[OADataFetcher alloc] init];
		[fetcher fetchDataWithRequest:request
                         delegate:self
                didFinishSelector:@selector(requestTokenTicket:didFinishWithData:)
                  didFailSelector:@selector(requestTokenTicket:didFailWithError:)];
	} else {
		NSLog(@"In Here");
	}
}


- (void)requestTokenTicket:(OAServiceTicket *)ticket didFinishWithData:(NSData *)data {
	NSString *responseBody = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	if (ticket.didSucceed) {
		requestToken = [[OAToken alloc] initWithHTTPResponseBody:responseBody];
		[requestToken storeInUserDefaultsWithServiceProviderName:@"mobitag.pictearth.com" prefix:@"MobitagRequest"];
		//NSString *xxx = [NSString stringWithFormat:@"https://fireeagle.yahoo.net/oauth/authorize?oauth_token=%@&&oauth_callback=mobitag://somethinghere",requestToken.key];
		//NSString *xxx = [NSString stringWithFormat:@"http://mobitag.pictearthusa.com/api/1.0/oauth/authorize?oauth_token=%@&oauth_callback=mobitag://somethinghere",requestToken.key];
		//NSString *xxx = [NSString stringWithFormat:@"http://bynotes.com/api/1.0/oauth/authorize?oauth_token=%@&&oauth_callback=mobitag://somethinghere",requestToken.key];
		NSString *xxx = [NSString stringWithFormat:@"http://localhost:8000/oauth/authorize?oauth_token=%@&oauth_callback=mobitag://somethinghere",requestToken.key];
		oauthUrlString = [xxx copy];
		UIAlertView *warning = [[[UIAlertView alloc]
                             initWithTitle:@"Opening Browser to Authenticate You"
                             message:@"Some nice message here to tell the user whats happening"
                             delegate:self 
                             cancelButtonTitle:nil
                             otherButtonTitles:@"OK", nil]autorelease];
		[warning show];
	} else {
		NSLog(@"Request Token Ticket Failed");
	}
}


- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger) buttonIndex {
	[[UIApplication sharedApplication] openURL:[NSURL URLWithString:oauthUrlString]];
}


- (BOOL)application: (UIApplication *)application handleOpenURL:(NSURL *)url {
	launchDefault = NO;
	//ByNotes
	//OAConsumer *consumer = [[OAConsumer alloc] initWithKey:@"yw1yag90ptqy290qp1qkcrqo0th4vco8" secret:@"p0syik010vu56migwh8wrcg4vy1ckco1"];
	//FireEagle
	//OAConsumer *consumer = [[OAConsumer alloc] initWithKey:@"DCMIA8IT4S1I" secret:@"sWBXgywgtsjhz7C7oMQBBsLHPXOVmJcg"];
	//Mobitag
	OAConsumer *consumer = [[[OAConsumer alloc] initWithKey:@"60vnbtmjffa0jcoel9tfc0jmlcc8lrnp" secret:@"10e7cer098glrzwysogwhajne7rafkrv"]autorelease];
	//NSURL *accessTokenURL = [NSURL URLWithString:@"https://fireeagle.yahooapis.com/oauth/access_token"];
	NSURL *accessTokenURL = [NSURL URLWithString:@"http://mobitag.pictearthusa.com/api/1.0/oauth/access_token"];
	//NSURL *accessTokenURL = [NSURL URLWithString:@"http://bynotes.com/api/1.0/oauth/access_token"];	
	requestToken = [[[OAToken alloc] initWithUserDefaultsUsingServiceProviderName:@"mobitag.pictearth.com" prefix:@"MobitagRequest"]autorelease];
	NSLog(@"requestToken in handleOpenURL = %@", requestToken);
	OAMutableURLRequest *request = [[[OAMutableURLRequest alloc] initWithURL:accessTokenURL
                                                                  consumer:consumer
                                                                     token:requestToken
                                                                     realm:nil 
                                                         signatureProvider:[[[OAHMAC_SHA1SignatureProvider alloc] init]autorelease]]autorelease];
	[request setHTTPMethod:@"POST"];
	OADataFetcher *fetcher = [[[OADataFetcher alloc] init]autorelease];
	[fetcher fetchDataWithRequest:request
                       delegate:self
              didFinishSelector:@selector(accessTokenTicket:didFinishWithData:)
                didFailSelector:@selector(accessTokenTicket:didFailWithError:)];
	return YES;
}


- (void) accessTokenTicket:(OAServiceTicket *)ticket didFinishWithData:(NSData *)data {
	if (ticket.didSucceed) {
		NSString *responseBody = [[[NSString alloc] initWithData:data
                                                    encoding:NSUTF8StringEncoding]autorelease];	
		accessToken = [[[OAToken alloc] initWithHTTPResponseBody:responseBody]autorelease];
		[accessToken storeInUserDefaultsWithServiceProviderName:@"mobitag.pictearth.com" prefix:@"MobitagAccess"];
		launchDefault = YES;
		[self postLaunch];
	} else {
		NSLog(@"accessTokenTicket Failed in didFinishWithData");
	}
}


- (void) testOAuthAccessProtected {
	accessToken = [[[OAToken alloc] initWithUserDefaultsUsingServiceProviderName:@"mobitag.pictearth.com" prefix:@"MobitagAccess"]autorelease];
	NSLog(@"accessToken in testOAuthAccess Protected = %@", accessToken);
	//ByNotes
	//OAConsumer *consumer = [[OAConsumer alloc] initWithKey:@"yw1yag90ptqy290qp1qkcrqo0th4vco8" secret:@"p0syik010vu56migwh8wrcg4vy1ckco1"];
	//FireEagle
	//OAConsumer *consumer = [[OAConsumer alloc] initWithKey:@"DCMIA8IT4S1I" secret:@"sWBXgywgtsjhz7C7oMQBBsLHPXOVmJcg"];
	//Mobitag
	OAConsumer *consumer = [[[OAConsumer alloc] initWithKey:@"60vnbtmjffa0jcoel9tfc0jmlcc8lrnp" secret:@"10e7cer098glrzwysogwhajne7rafkrv"]autorelease];
	NSURL *url = [NSURL URLWithString:@"http://mobitag.pictearthusa.com/api/1.0/rest/oauth/user/profile.json"];
	//NSURL *url = [NSURL URLWithString:@"https://fireeagle.yahooapis.com/api/0.1/user.json"];
	//NSURL *url = [NSURL URLWithString:@"http://bynotes.com/api/1.0/rest/oauth/position/position.json"];	
  OAMutableURLRequest *request = [[[OAMutableURLRequest alloc] initWithURL:url
                                                                  consumer:consumer
                                                                     token:accessToken
                                                                     realm:nil
                                                         signatureProvider:[[[OAPlaintextSignatureProvider alloc] init]autorelease]]autorelease];
	[request setHTTPMethod:@"GET"];	
	//OARequestParameter *addressParam = [[OARequestParameter alloc] initWithName:@"address" value:@"319 S. Ditmar #1 Oceanside, CA"];
	//NSArray *params = [NSArray arrayWithObjects:addressParam,  nil];
  //[request setParameters:params];
  
  OADataFetcher *fetcher = [[[OADataFetcher alloc] init]autorelease];
  [fetcher fetchDataWithRequest:request
                       delegate:self
              didFinishSelector:@selector(apiTicket:didFinishWithData:)
                didFailSelector:@selector(apiTicket:didFailWithError:)];
}


- (void) apiTicket:(OAServiceTicket *)ticket didFinishWithData:(NSData *)data {
	//NSString *responseBody = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]autorelease];	
	/*
   //SBJSON *jsonParser = [SBJSON new];
   NSDictionary *feed = [jsonParser objectWithString:responseBody error:NULL];
   NSLog(@"user: %@", [feed valueForKey:@"user"]);
   NSDictionary *user = (NSDictionary *)[feed valueForKey:@"user"];
   NSArray *location_hierarchy = (NSArray *)[user valueForKey:@"location_hierarchy"];
   int ndx;
   for (ndx = 0; ndx < location_hierarchy.count; ndx++) {
   NSDictionary *location = (NSDictionary *)[location_hierarchy objectAtIndex:ndx];
   NSLog(@"name: %@", [location valueForKey:@"name"]);
   NSLog(@"woeid: %@", [location valueForKey:@"woeid"]);
   NSLog(@"place_id: %@", [location valueForKey:@"place_id"]);
   }
	 */
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

- (NSManagedObjectContext *)bgMoc {
	
	if (bgMoc_ != nil) {
		return bgMoc_;
	}
	
	NSPersistentStoreCoordinator *coordinator = [self createPersistentStoreCoordinator];
	if (coordinator != nil) {
		bgMoc_ = [[NSManagedObjectContext alloc] init];
		[bgMoc_ setPersistentStoreCoordinator:coordinator];
	}
	return bgMoc_;
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

- (NSPersistentStoreCoordinator *) createPersistentStoreCoordinator {
	
	NSURL *storeURL = [NSURL fileURLWithPath: [[self applicationDocumentsDirectory] stringByAppendingPathComponent: @"iBurn.sqlite"]];
	
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
