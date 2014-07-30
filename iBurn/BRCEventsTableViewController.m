//
//  BRCEventsTableViewController.m
//  iBurn
//
//  Created by Christopher Ballinger on 7/28/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCEventsTableViewController.h"
#import "BRCDatabaseManager.h"
#import "BRCEventObjectTableViewCell.h"

@interface BRCEventsTableViewController ()
@end

@implementation BRCEventsTableViewController

- (NSArray *) segmentedControlInfo {
    NSArray *newTitles = @[@[@"Time", @(BRCDatabaseViewExtensionTypeUnknown)]];
    return [newTitles arrayByAddingObjectsFromArray:[super segmentedControlInfo]];
}

- (Class) cellClass {
    return [BRCEventObjectTableViewCell class];
}

@end
