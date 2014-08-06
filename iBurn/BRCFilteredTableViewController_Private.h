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

@property (nonatomic, strong, readwrite) NSString *favoritesViewName;
@property (nonatomic, strong, readwrite) NSString *distanceViewName;

@property (nonatomic) BOOL updatingDistanceInformation;

/** override this in subclasses */
- (void) setupViewNames;

- (void) updateAllMappings;

/** override this in subclasses */
- (void) setupMappingsDictionary;

- (void) refreshDistanceInformationFromLocation:(CLLocation*)fromLocation;
- (BOOL) shouldRefreshDistanceInformationForNewLocation:(CLLocation*)newLocation;

- (NSArray *) segmentedControlInfo;
- (Class) cellClass;

@end
