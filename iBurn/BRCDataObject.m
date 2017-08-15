//
//  BRCDataObject.m
//  iBurn
//
//  Created by Christopher Ballinger on 7/28/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCDataObject.h"
#import "BRCDataObject_Private.h"
#import "BRCAppDelegate.h"
#import "BRCArtObject.h"
#import "BRCEventObject.h"
#import "BRCCampObject.h"

@interface BRCDataObject()
@property (nonatomic, readonly) CLLocationDegrees latitude;
@property (nonatomic, readonly) CLLocationDegrees longitude;


@property (nonatomic, readonly) CLLocationDegrees burnerMapLongitude;
@property (nonatomic, readonly) CLLocationDegrees burnerMapLatitude;
@end

@implementation BRCDataObject
@dynamic location;
@dynamic coordinate;
@dynamic burnerMapLocation, burnerMapCoordinate, yapKey;

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    return @{NSStringFromSelector(@selector(title)): @"name",
             NSStringFromSelector(@selector(uniqueID)): @"uid",
             NSStringFromSelector(@selector(detailDescription)): @"description",
             NSStringFromSelector(@selector(email)): @"contact_email",
             NSStringFromSelector(@selector(url)): @"url",
             NSStringFromSelector(@selector(year)): @"year",
             NSStringFromSelector(@selector(latitude)): @"location.gps_latitude",
             NSStringFromSelector(@selector(longitude)): @"location.gps_longitude",
             NSStringFromSelector(@selector(playaLocation)): @"location.string",
             NSStringFromSelector(@selector(burnerMapLatitude)): @"burnermap_location.gps_latitude",
             NSStringFromSelector(@selector(burnerMapLongitude)): @"burnermap_location.gps_longitude",
             NSStringFromSelector(@selector(burnerMapLocationString)): @"burnermap_location.string"};
}

- (CLLocation*) location {
    CLLocationCoordinate2D coordinate = self.coordinate;
    if (!CLLocationCoordinate2DIsValid(coordinate)) {
        return nil;
    }
    return [[CLLocation alloc] initWithLatitude:coordinate.latitude longitude:coordinate.longitude];
}

- (CLLocation*) burnerMapLocation {
    CLLocationCoordinate2D coordinate = self.burnerMapCoordinate;
    if (!CLLocationCoordinate2DIsValid(coordinate)) {
        return nil;
    }
    return [[CLLocation alloc] initWithLatitude:coordinate.latitude longitude:coordinate.longitude];
}

- (CLLocationCoordinate2D) burnerMapCoordinate {
    if (_burnerMapLatitude == 0 || _burnerMapLongitude == 0) {
        return kCLLocationCoordinate2DInvalid;
    }
    return CLLocationCoordinate2DMake(_burnerMapLatitude, _burnerMapLongitude);
}

- (void) setBurnerMapCoordinate:(CLLocationCoordinate2D)burnerMapCoordinate {
    if (!CLLocationCoordinate2DIsValid(burnerMapCoordinate)) {
        return;
    }
    _burnerMapLatitude = burnerMapCoordinate.latitude;
    _burnerMapLongitude = burnerMapCoordinate.longitude;
}

- (CLLocationCoordinate2D) coordinate {
    if (_latitude == 0 || _longitude == 0) {
        return kCLLocationCoordinate2DInvalid;
    }
    return CLLocationCoordinate2DMake(_latitude, _longitude);
}

- (void) setCoordinate:(CLLocationCoordinate2D)coordinate {
    if (!CLLocationCoordinate2DIsValid(coordinate)) {
        return;
    }
    _latitude = coordinate.latitude;
    _longitude = coordinate.longitude;
}

- (void)setNilValueForKey:(NSString *)key {
    if (NSStringFromSelector(@selector(latitude))) {
        _latitude = 0;
    } else if (NSStringFromSelector(@selector(longitude))) {
        _longitude = 0;
    } else if (NSStringFromSelector(@selector(burnerMapLatitude))) {
        _burnerMapLatitude = 0;
    } else if (NSStringFromSelector(@selector(burnerMapLongitude))) {
        _burnerMapLongitude = 0;
    } else {
        [super setNilValueForKey:key];
    }
}

+ (NSValueTransformer *)urlJSONTransformer {
    return [NSValueTransformer valueTransformerForName:MTLURLValueTransformerName];
}

- (CLLocationDistance) distanceFromLocation:(CLLocation*)location {
    if (!location) {
        return CLLocationDistanceMax;
    }
    CLLocation *objectLocation = self.location;
    if (!objectLocation) {
        objectLocation = self.burnerMapLocation;
    }
    if (!objectLocation) {
        return CLLocationDistanceMax;
    }
    CLLocationDistance distance = [location distanceFromLocation:objectLocation];
    return distance;
}


- (NSString*) yapKey {
    return _uniqueID;
}

// MARK: Mantle encoding behavior

/// Determines how the +propertyKeys of the class are encoded into an archive.
/// The values of this dictionary should be boxed MTLModelEncodingBehavior
/// values.
///
/// Any keys not present in the dictionary will be excluded from the archive.
///
/// Subclasses overriding this method should combine their values with those of
/// `super`.
///
/// Returns a dictionary mapping the receiver's +propertyKeys to default encoding
/// behaviors. If a property is an object with `weak` semantics, the default
/// behavior is MTLModelEncodingBehaviorConditional; otherwise, the default is
/// MTLModelEncodingBehaviorUnconditional.
+ (NSDictionary *)encodingBehaviorsByPropertyKey {
    NSMutableDictionary *behaviors = [[super encodingBehaviorsByPropertyKey] mutableCopy];
    // these properties are dynamically generated
    [[self excludedPropertyKeys] enumerateObjectsUsingBlock:^(NSString * _Nonnull key, BOOL * _Nonnull stop) {
        [behaviors setObject:@(MTLModelEncodingBehaviorExcluded) forKey:key];
    }];
    return behaviors;
}

+ (MTLPropertyStorage)storageBehaviorForPropertyWithKey:(NSString *)propertyKey {
    NSSet<NSString*> *excludedPropertyKeys = [self excludedPropertyKeys];
    if ([excludedPropertyKeys containsObject:propertyKey]) {
        return MTLPropertyStorageNone;
    }
    return [super storageBehaviorForPropertyWithKey:propertyKey];
}

+ (NSSet<NSString*>*) excludedPropertyKeys {
    static dispatch_once_t onceToken;
    static NSSet<NSString*> *excludedPropertyKeysSet = nil;
    dispatch_once(&onceToken, ^{
        NSArray<NSString*> *keys = @[NSStringFromSelector(@selector(coordinate)),
                                     NSStringFromSelector(@selector(location)),
                                     NSStringFromSelector(@selector(burnerMapLocation)),
                                     NSStringFromSelector(@selector(burnerMapCoordinate)),
                                     NSStringFromSelector(@selector(yapKey)),
                                     NSStringFromSelector(@selector(brc_markerImage))];
        excludedPropertyKeysSet = [NSSet setWithArray:keys];
    });
    return excludedPropertyKeysSet;
}

// MARK: BRCMetadataProtocol

- (BRCObjectMetadata*) metadataWithTransaction:(YapDatabaseReadTransaction*)transaction {
    id metadata = [transaction metadataForKey:self.yapKey inCollection:self.yapCollection];
    if ([metadata isKindOfClass:BRCObjectMetadata.class]) {
        return metadata;
    }
    return [BRCObjectMetadata new];
}

- (void) replaceMetadata:(nullable BRCObjectMetadata*)metadata transaction:(YapDatabaseReadWriteTransaction*)transaction {
    [transaction replaceMetadata:metadata forKey:self.yapKey inCollection:self.yapCollection];
}

- (void) touchMetadataWithTransaction:(YapDatabaseReadWriteTransaction*)transaction {
    [transaction touchMetadataForKey:self.yapKey inCollection:self.yapCollection];
}

@end

@implementation BRCDataObject (MarkerImage)

- (UIImage*) brc_markerImage {
    UIImage *markerImage = nil;
    Class dataObjectClass = [self class];
    if (dataObjectClass == [BRCArtObject class]) {
        markerImage = [UIImage imageNamed:@"BRCBluePin"];
    } else if (dataObjectClass == [BRCEventObject class]) {
        BRCEventObject *eventObject = (BRCEventObject*)self;
        markerImage = [eventObject markerImageForEventStatus:[NSDate date]];
    } else if (dataObjectClass == [BRCCampObject class]) {
        markerImage = [UIImage imageNamed:@"BRCPurplePin"];
    } else {
        markerImage = [UIImage imageNamed:@"BRCPurplePin"];
    }
    return markerImage;
}

@end
