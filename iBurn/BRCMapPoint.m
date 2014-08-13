//
//  BRCMapPoint.m
//  iBurn
//
//  Created by Christopher Ballinger on 8/12/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCMapPoint.h"
#import "MTLModel+NSCoding.h"
#import "RMAnnotation.h"

@interface BRCMapPoint()
@property (nonatomic, strong, readwrite) NSString *uuid;
@property (nonatomic) CLLocationDegrees latitude;
@property (nonatomic) CLLocationDegrees longitude;
@property (nonatomic, strong, readwrite) NSDate *creationDate;
@end

@implementation BRCMapPoint
@dynamic coordinate;

- (instancetype) initWithTitle:(NSString*)title coordinate:(CLLocationCoordinate2D)coordinate {
    if (self = [super init]) {
        self.title = title;
        self.coordinate = coordinate;
        self.uuid = [[NSUUID UUID] UUIDString];
        self.creationDate = [NSDate date];
        self.modifiedDate = [NSDate date];
    }
    return self;
}

+ (NSString*) collection {
    return NSStringFromClass([self class]);
}

- (CLLocationCoordinate2D) coordinate {
    return CLLocationCoordinate2DMake(self.latitude, self.longitude);
}

- (void) setCoordinate:(CLLocationCoordinate2D)coordinate {
    self.latitude = coordinate.latitude;
    self.longitude = coordinate.longitude;
}

+ (NSDictionary *)encodingBehaviorsByPropertyKey {
    NSMutableDictionary *behaviors = [NSMutableDictionary dictionaryWithDictionary:[super encodingBehaviorsByPropertyKey]];
    [behaviors setObject:@(MTLModelEncodingBehaviorExcluded) forKey:NSStringFromSelector(@selector(coordinate))];
    return behaviors;
}

@end
