//
//  BRCMapPoint.h
//  iBurn
//
//  Created by Christopher Ballinger on 8/12/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "MTLModel.h"
#import <CoreLocation/CoreLocation.h>

@interface BRCMapPoint : MTLModel

@property (nonatomic, strong, readonly) NSString *uuid;
@property (nonatomic, strong, readwrite) NSString *title;
@property (nonatomic, strong, readonly) NSDate *creationDate;
@property (nonatomic, readwrite) CLLocationCoordinate2D coordinate;

- (instancetype) initWithTitle:(NSString*)title coordinate:(CLLocationCoordinate2D)coordinate;

+ (NSString*) collection;

@end
