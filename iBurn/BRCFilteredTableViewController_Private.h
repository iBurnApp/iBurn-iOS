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

- (void) updateAllMappings;
- (void) setupMappingsDictionary;
- (void) refreshDistanceInformationFromLocation:(CLLocation*)fromLocation;

- (NSArray *) segmentedControlInfo;
- (Class) cellClass;
- (NSString*) selectedDataObjectGroup;

@end
