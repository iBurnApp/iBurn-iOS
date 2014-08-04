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

@interface BRCDataObject()
@property (nonatomic, readonly) CLLocationDegrees latitude;
@property (nonatomic, readonly) CLLocationDegrees longitude;

// This is to prevent clobbering the value during re-import of data
// however, it doesn't work...
@property (nonatomic, strong, readwrite) NSNumber *isFavoriteNumber;

@end

@implementation BRCDataObject
@dynamic location;
@dynamic isFavorite;

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    return @{NSStringFromSelector(@selector(title)): @"name",
             NSStringFromSelector(@selector(uniqueID)): @"id",
             NSStringFromSelector(@selector(detailDescription)): @"description",
             NSStringFromSelector(@selector(email)): @"contact_email",
             NSStringFromSelector(@selector(url)): @"url",
             NSStringFromSelector(@selector(latitude)): @"latitude",
             NSStringFromSelector(@selector(longitude)): @"longitude",
             NSStringFromSelector(@selector(year)): @"year.year",
             NSStringFromSelector(@selector(playaLocation)):@"location"};
}

- (void) setIsFavorite:(BOOL)isFavorite {
    self.isFavoriteNumber = @(isFavorite);
}

- (BOOL) isFavorite {
    return self.isFavoriteNumber.boolValue;
}

- (CLLocation*) location {
    if (self.latitude == 0 || self.longitude == 0) {
        return nil;
    }
    return [[CLLocation alloc] initWithLatitude:self.latitude longitude:self.longitude];
}

+ (NSValueTransformer *)uniqueIDJSONTransformer {
    return [MTLValueTransformer transformerWithBlock:^NSString*(NSNumber* number) {
        return number.stringValue;
    }];
}

+ (NSValueTransformer *)urlJSONTransformer {
    return [NSValueTransformer valueTransformerForName:MTLURLValueTransformerName];
}

+ (NSString *)collection
{
    return NSStringFromClass([self class]);
}

@end
