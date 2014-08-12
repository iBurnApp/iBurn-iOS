//
//  BRCMapPoint.m
//  iBurn
//
//  Created by Christopher Ballinger on 8/12/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCMapPoint.h"

@interface BRCMapPoint()
@property (nonatomic, strong, readwrite) NSString *uuid;
@end

@implementation BRCMapPoint

- (instancetype) initWithTitle:(NSString*)title coordinate:(CLLocationCoordinate2D)coordinate {
    if (self = [super init]) {
        self.title = title;
        self.coordinate = coordinate;
        self.uuid = [[NSUUID UUID] UUIDString];
    }
    return self;
}

+ (NSString*) collection {
    return NSStringFromClass([self class]);
}

@end
