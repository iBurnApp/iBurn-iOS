//
//  BRCFilteredTableViewController_Private.h
//  iBurn
//
//  Created by Christopher Ballinger on 7/31/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCFilteredTableViewController.h"

@interface BRCFilteredTableViewController ()
@property (nonatomic, strong) NSMutableDictionary *mappingsDictionary;
@property (nonatomic, strong) YapDatabaseConnection *databaseConnection;
@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, strong) CLLocation *lastDistanceUpdateLocation;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicatorView;


@property (nonatomic) BOOL updatingDistanceInformation;

/** override these in subclasses */
- (void) setupDatabaseExtensionNames;
- (void) registerDatabaseExtensions;
- (void) setupMappingsDictionary;
- (void) updateAllMappingsWithCompletionBlock:(dispatch_block_t)completionBlock;

- (void) refreshDistanceInformationFromLocation:(CLLocation*)fromLocation;
- (BOOL) shouldRefreshDistanceInformationForNewLocation:(CLLocation*)newLocation;

- (NSArray *) segmentedControlInfo;
- (Class) cellClass;
- (NSSet *) allowedCollections;

- (BOOL)isSearchResultsControllerTableView:(UITableView *)tableView;
@end
