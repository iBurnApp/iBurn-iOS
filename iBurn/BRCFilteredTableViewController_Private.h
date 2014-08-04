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
@property (nonatomic, strong) CLLocation *lastDistanceUpdateLocation;

- (void) updateAllMappings;
- (void) refreshDistanceInformation;

// Override these in subclasses
- (NSArray *) segmentedControlInfo;
- (Class) cellClass;
- (void) setupMappingsDictionary;
- (NSString*) selectedDataObjectGroup;

@end
