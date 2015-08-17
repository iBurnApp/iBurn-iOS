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
#import "BRCBreadcrumbPoint.h"

@interface BRCMapPoint()
@property (nonatomic) CLLocationDegrees latitude;
@property (nonatomic) CLLocationDegrees longitude;
@end

@implementation BRCMapPoint
@dynamic coordinate;
@synthesize uuid = _uuid;

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
             NSStringFromSelector(@selector(longitude)): @"geometry.coordinates[0]",
             NSStringFromSelector(@selector(latitude)): @"geometry.coordinates[1]",
             };
}

- (instancetype) initWithTitle:(NSString*)title coordinate:(CLLocationCoordinate2D)coordinate type:(BRCMapPointType)type {
    if (self = [super init]) {
        _title = title;
        self.coordinate = coordinate;
        _uuid = [[NSUUID UUID] UUIDString];
        _creationDate = [NSDate date];
        _type = type;
    }
    return self;
}

- (NSString*) uuid {
    if (!_uuid) {
        _uuid = [[NSUUID UUID] UUIDString];
    }
    return _uuid;
}

+ (NSString*) collection {
    return NSStringFromClass([self class]);
}

- (CLLocationCoordinate2D) coordinate {
    if (_latitude == 0 || _longitude == 0) {
        return kCLLocationCoordinate2DInvalid;
    }
    return CLLocationCoordinate2DMake(_latitude, _longitude);
}

- (CLLocation*) location {
    CLLocationCoordinate2D coordinate = self.coordinate;
    return [[CLLocation alloc] initWithLatitude:coordinate.latitude longitude:coordinate.longitude];
}

- (void) setCoordinate:(CLLocationCoordinate2D)coordinate {
    _latitude = coordinate.latitude;
    _longitude = coordinate.longitude;
}

+ (NSDictionary *)encodingBehaviorsByPropertyKey {
    NSMutableDictionary *behaviors = [NSMutableDictionary dictionaryWithDictionary:[super encodingBehaviorsByPropertyKey]];
    [behaviors setObject:@(MTLModelEncodingBehaviorExcluded) forKey:NSStringFromSelector(@selector(coordinate))];
    return behaviors;
}

+ (NSValueTransformer*)typeJSONTransformer {
    return [MTLValueTransformer transformerUsingForwardBlock:^id(id value, BOOL *success, NSError *__autoreleasing *error) {
        NSNumber *typeValue = nil;
        if ([value isKindOfClass:[NSString class]]) {
            NSString *refString = value;
            BRCMapPointType type = BRCMapPointTypeUnknown;
            if ([refString isEqualToString:@"EmergencyClinic"] ||
                [refString isEqualToString:@"firstAid"]) {
                type = BRCMapPointTypeMedical;
            } else if ([refString isEqualToString:@"ranger"]) {
                type = BRCMapPointTypeRanger;
            } else if ([refString isEqualToString:@"toilet"]) {
                type = BRCMapPointTypeToilet;
            }
            typeValue = @(type);
        }
        return typeValue;
    }];
}

/*
- (NSValueTransformer*)coordinateJSONTransformer {
    return [MTLValueTransformer transformerUsingForwardBlock:^id(id value, BOOL *success, NSError *__autoreleasing *error) {
        //CLLocationCoordinate2D coordinate
        if ([value isKindOfClass:[NSArray class]]) {
            NSArray *coordArray = value;
            
        }
    }];
}
*/

/** BRCUserMapPoint for editable user points, BRCMapPoint for fixed locations */
+ (Class) classForType:(BRCMapPointType)type {
    switch (type) {
        case BRCMapPointTypeUserBreadcrumb:
            return [BRCBreadcrumbPoint class];
            break;
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
