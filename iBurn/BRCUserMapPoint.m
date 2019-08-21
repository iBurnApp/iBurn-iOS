//
//  BRCUserMapPoint.m
//  iBurn
//
//  Created by Christopher Ballinger on 8/15/15.
//  Copyright (c) 2015 Burning Man Earth. All rights reserved.
//

#import "BRCUserMapPoint.h"
#import "iBurn-Swift.h"

@implementation BRCUserMapPoint

- (instancetype) initWithTitle:(NSString *)title coordinate:(CLLocationCoordinate2D)coordinate type:(BRCMapPointType)type {
    if (self = [super initWithTitle:title coordinate:coordinate type:type]) {
        self.modifiedDate = [NSDate now];
    }
    return self;
}

@end
