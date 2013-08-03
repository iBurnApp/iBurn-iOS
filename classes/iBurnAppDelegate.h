//
//  iBurnAppDelegate.h
//  iBurn
//
//  Created by Jeffrey Johnson on 2009-01-11.
//  Copyright Burning Man Earth 2009. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <sqlite3.h>
#import <CoreData/CoreData.h>
#import "CampNodeController.h"


@class Reachability;

@interface iBurnAppDelegate : NSObject <UIApplicationDelegate, UITabBarControllerDelegate, UIAlertViewDelegate, NodeFetchDelegate> {
	BOOL launchDefault;
  UIWindow *window;
  UITabBarController *tabBarController;
	NSMutableArray *themeCamps;
	sqlite3 *database;
	NSString *databasePath;
	NSString *oauthUrlString;
	Reachability* reachability;
  NodeController *campNodeController, *artNodeController, *eventNodeController;
	NSManagedObjectContext *managedObjectContext_;
  NSManagedObjectContext *bgMoc_;
	NSManagedObjectModel *managedObjectModel_;
	NSPersistentStoreCoordinator *persistentStoreCoordinator_;
  BOOL embargoed;
}

@property BOOL launchDefault;
@property (nonatomic, strong) IBOutlet UIWindow *window;
@property (nonatomic, strong) NSMutableArray *themeCamps;
@property (nonatomic, strong) NodeController *campNodeController, *artNodeController, *eventNodeController;


@property (nonatomic, strong, readonly) NSManagedObjectContext *managedObjectContext, *bgMoc;
@property (nonatomic, strong, readonly) NSManagedObjectModel *managedObjectModel;
@property (nonatomic, strong, readonly) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (nonatomic, strong) UITabBarController *tabBarController;
@property (nonatomic, assign) BOOL embargoed;

- (NSString *)applicationDocumentsDirectory;
- (BOOL) canConnectToInternet;
- (void) downloadMaps:(BOOL) refreshTiles;
- (NSString*) getStoredPassword;
- (BOOL) checkPassword:(NSString*) password;
- (void) liftEmbargo;

@end

