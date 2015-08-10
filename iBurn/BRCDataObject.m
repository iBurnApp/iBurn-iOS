//
//  BRCDataObject.m
//  iBurn
//
//  Created by Christopher Ballinger on 7/28/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCDataObject.h"
#import "MTLValueTransformer.h"
#import "NSValueTransformer+MTLPredefinedTransformerAdditions.h"
#import "BRCDataObject_Private.h"
#import "BRCAppDelegate.h"
@import Mantle;

@interface BRCDataObject()
@property (nonatomic, readonly) CLLocationDegrees latitude;
@property (nonatomic, readonly) CLLocationDegrees longitude;
@end

@implementation BRCDataObject
@dynamic location;
@dynamic coordinate;

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    return @{NSStringFromSelector(@selector(title)): @"name",
             NSStringFromSelector(@selector(uniqueID)): @"id",
             NSStringFromSelector(@selector(detailDescription)): @"description",
             NSStringFromSelector(@selector(email)): @"contact_email",
             NSStringFromSelector(@selector(url)): @"url",
             NSStringFromSelector(@selector(latitude)): @"latitude",
             NSStringFromSelector(@selector(longitude)): @"longitude",
             NSStringFromSelector(@selector(year)): @"year.year",
             NSStringFromSelector(@selector(playaLocation)): @"location"};
}

- (CLLocation*) location {
    CLLocationCoordinate2D coordinate = self.coordinate;
    if (!CLLocationCoordinate2DIsValid(coordinate)) {
        return nil;
    }
    return [[CLLocation alloc] initWithLatitude:coordinate.latitude longitude:coordinate.longitude];
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

+ (NSValueTransformer *)uniqueIDJSONTransformer {
    return [MTLValueTransformer transformerUsingForwardBlock:^id(id value, BOOL *success, NSError *__autoreleasing *error) {
        *success = NO;
        if ([value isKindOfClass:[NSNumber class]]) {
            *success = YES;
            return ((NSNumber *)value).stringValue;
        }
        return nil;
        
    } reverseBlock:^id(id value, BOOL *success, NSError *__autoreleasing *error) {
        *success = NO;
        if ([value isKindOfClass:[NSString class]]) {
            *success = YES;
            return @(((NSString *)value).integerValue);
        }
        return nil;
    }];
}

+ (NSValueTransformer *)urlJSONTransformer {
    return [NSValueTransformer valueTransformerForName:MTLURLValueTransformerName];
}

+ (NSString *)collection
{
    return NSStringFromClass([self class]);
}

// this is a bad hack
- (CLLocationDistance) distanceFromUser {
    CLLocation *currentLocation = [BRCAppDelegate sharedAppDelegate].locationManager.location;
    CLLocation *objectLocation = self.location;
    if (!currentLocation || !objectLocation) {
        return CLLocationDistanceMax;
    }
    CLLocationDistance distance = [currentLocation distanceFromLocation:objectLocation];
    return distance;
}

- (void) mergeValueForKey:(NSString *)key fromModel:(id<MTLModel>)model {
    // Don't overwrite favorites from merged model data
    if ([key isEqualToString:NSStringFromSelector(@selector(isFavorite))]) {
        return;
    }
    [super mergeValueForKey:key fromModel:model];
}

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
    [behaviors setObject:@(MTLModelEncodingBehaviorExcluded) forKey:NSStringFromSelector(@selector(coordinate))];
    [behaviors setObject:@(MTLModelEncodingBehaviorExcluded) forKey:NSStringFromSelector(@selector(location))];
    return behaviors;
}

@end
