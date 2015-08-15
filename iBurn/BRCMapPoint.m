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
#import "BRCUserMapPoint.h"

@interface BRCMapPoint()
@property (nonatomic, strong, readwrite) NSString *uuid;
@property (nonatomic) CLLocationDegrees latitude;
@property (nonatomic) CLLocationDegrees longitude;
@property (nonatomic, strong, readwrite) NSDate *creationDate;
@end

@implementation BRCMapPoint
@dynamic coordinate;

/*
{
    "type": "Feature",
    "geometry": {
        "type": "Point",
        "coordinates": [
                        -119.21001900000002,
                        40.779943
                        ]
    },
    "properties": {
        "name": "First Aid (Main)",
        "ref": "EmergencyClinic"
    }
},
 
 ## Types (unsupported):
 * airport
 * services
 * dpw
 * center
 * centerCamp
 * 8entrance
 * 12entrance
 * greeters
 * ice
 
 ## Types (supported):
 * EmergencyClinic -> BRCMapPointTypeMedical
 * firstAid -> BRCMapPointTypeMedical
 * ranger -> BRCMapPointTypeRanger
 Note there is both "firstAid" and "EmergencyClinic" for medical
 * toilet -> BRCMapPointTypeToilet
 
 */
+ (NSDictionary*) JSONKeyPathsByPropertyKey {
    return @{NSStringFromSelector(@selector(title)): @"properties.name",
             NSStringFromSelector(@selector(type)): @"properties.ref",
             NSStringFromSelector(@selector(coordinate)): @"geometry.coordinates"};
}

- (instancetype) initWithTitle:(NSString*)title coordinate:(CLLocationCoordinate2D)coordinate type:(BRCMapPointType)type {
    if (self = [super init]) {
        self.title = title;
        self.coordinate = coordinate;
        self.uuid = [[NSUUID UUID] UUIDString];
        self.creationDate = [NSDate date];
        _type = type;
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


/** BRCUserMapPoint for editable user points, BRCMapPoint for fixed locations */
+ (Class) classForType:(BRCMapPointType)type {
    switch (type) {
        case BRCMapPointTypeUserBreadcrumb:
        case BRCMapPointTypeUserBike:
        case BRCMapPointTypeUserCamp:
        case BRCMapPointTypeUserHeart:
        case BRCMapPointTypeUserHome:
        case BRCMapPointTypeUserStar:
        case BRCMapPointTypeUnknown:
            return [BRCUserMapPoint class];
            break;
        case BRCMapPointTypeMedical:
        case BRCMapPointTypeRanger:
        case BRCMapPointTypeToilet:
            return [BRCMapPoint class];
        default:
            return nil;
            break;
    }
}

@end
