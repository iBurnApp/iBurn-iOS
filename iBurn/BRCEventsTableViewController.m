//
//  BRCEventsTableViewController.m
//  iBurn
//
//  Created by Christopher Ballinger on 7/28/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCEventsTableViewController.h"

@interface BRCEventsTableViewController ()
@end

@implementation BRCEventsTableViewController

- (NSArray *) segmentedControlTitles {
    return [@[@"Time"] arrayByAddingObjectsFromArray:[super segmentedControlTitles]];
}

@end
