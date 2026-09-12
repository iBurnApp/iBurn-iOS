//
//  BRCMapPoint.m
//  iBurn
//
//  Created by Christopher Ballinger on 8/12/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCMapPoint.h"
#import "BRCUserMapPoint.h"
#import "BRCBreadcrumbPoint.h"
#import "iBurn-Swift.h"
@import PlayaGeocoder;

@interface BRCMapPoint()
@property (nonatomic) CLLocationDegrees latitude;
@property (nonatomic) CLLocationDegrees longitude;
@end

@implementation BRCMapPoint
@dynamic coordinate;

- (instancetype) initWithTitle:(NSString*)title coordinate:(CLLocationCoordinate2D)coordinate type:(BRCMapPointType)type {
    if (self = [super init]) {
        _uniqueID = [[NSUUID UUID] UUIDString];
        _title = title;
        self.coordinate = coordinate;
        _creationDate = [NSDate present];
        _type = type;
    }
    return self;
}

- (CLLocationCoordinate2D) coordinate {
    // A zero in either component means "never set" for this model, and NaN/inf means
    // something upstream handed us garbage (a degenerate map viewport, a corrupt decode).
    // Both have to read as invalid here: MapLibre projects this straight into a
    // CALayer position, where a NaN is a fatal CALayerInvalidGeometry exception.
    if (_latitude == 0 || _longitude == 0) {
        return kCLLocationCoordinate2DInvalid;
    }
    CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(_latitude, _longitude);
    if (!isfinite(coordinate.latitude) || !isfinite(coordinate.longitude) ||
        !CLLocationCoordinate2DIsValid(coordinate)) {
        return kCLLocationCoordinate2DInvalid;
    }
    return coordinate;
}

- (CLLocation*) location {
    CLLocationCoordinate2D coordinate = self.coordinate;
    if (!CLLocationCoordinate2DIsValid(coordinate)) {
        return nil;
    }
    return [[CLLocation alloc] initWithLatitude:coordinate.latitude longitude:coordinate.longitude];
}

- (void) setCoordinate:(CLLocationCoordinate2D)coordinate {
    [self willChangeValueForKey:NSStringFromSelector(@selector(coordinate))];
    _latitude = coordinate.latitude;
    _longitude = coordinate.longitude;
    [self didChangeValueForKey:NSStringFromSelector(@selector(coordinate))];
}

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
    }
}

- (UIImage*) image {
    switch (self.type) {
        case BRCMapPointTypeUserBike:
            return [UIImage imageNamed:@"BRCUserPinBike"];
        case BRCMapPointTypeUserHome:
            return [UIImage imageNamed:@"BRCUserPinHome"];
        case BRCMapPointTypeUserStar:
            return [UIImage imageNamed:@"BRCUserPinStar"];
        default:
            return [UIImage imageNamed:@"BRCUserPinStar"];
    }
}

- (NSString*) title {
    switch (self.type) {
        case BRCMapPointTypeUserHome:
            return @"Home";
        case BRCMapPointTypeUserBike:
            return @"Bike";
        case BRCMapPointTypeUserStar: {
            if (_title) {
                return _title;
            }
            return @"Favorite";
        }
        default:
            return _title;
    }
}

- (nullable NSString*) subtitle {
    return [PlayaGeocoder.shared syncReverseLookup:self.coordinate];
}

@end
