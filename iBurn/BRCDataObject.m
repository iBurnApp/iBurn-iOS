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

@interface BRCDataObject()
@property (nonatomic, readonly) CLLocationDegrees latitude;
@property (nonatomic, readonly) CLLocationDegrees longitude;
@end

@implementation BRCDataObject
@dynamic coordinate;

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    return @{NSStringFromSelector(@selector(title)): @"title",
             NSStringFromSelector(@selector(uniqueID)): @"id",
             NSStringFromSelector(@selector(detailDescription)): @"description",
             NSStringFromSelector(@selector(email)): @"contact_email",
             NSStringFromSelector(@selector(url)): @"url",
             NSStringFromSelector(@selector(latitude)): @"latitude",
             NSStringFromSelector(@selector(longitude)): @"longitude"};
}

- (CLLocationCoordinate2D) coordinate {
    return CLLocationCoordinate2DMake(self.latitude, self.longitude);
}

+ (NSValueTransformer *)uniqueIDJSONTransformer {
    return [MTLValueTransformer transformerWithBlock:^NSString*(NSNumber* number) {
        return number.stringValue;
    }];
}

+ (NSValueTransformer *)yearJSONTransformer {
    return [MTLValueTransformer transformerWithBlock:^NSString*(NSDictionary * dictionary) {
        return [dictionary objectForKey:@"year"];
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
