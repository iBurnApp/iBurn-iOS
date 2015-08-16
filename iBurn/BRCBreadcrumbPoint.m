//
//  BRCBreadcrumbPoint.m
//  iBurn
//
//  Created by Christopher Ballinger on 8/15/15.
//  Copyright (c) 2015 Burning Man Earth. All rights reserved.
//

#import "BRCBreadcrumbPoint.h"

@implementation BRCBreadcrumbPoint

- (instancetype) initWithLocation:(CLLocation *)location {
    NSParameterAssert(location != nil);
    if (!location) {
        return nil;
    }
    if (self = [super initWithTitle:nil coordinate:location.coordinate type:BRCMapPointTypeUserBreadcrumb]) {
        self.creationDate = location.timestamp;
    }
    return self;
}

@end
