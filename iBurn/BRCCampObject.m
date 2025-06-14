//
//  BRCCampObject.m
//  iBurn
//
//  Created by Christopher Ballinger on 7/28/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCCampObject.h"
#import "BRCCampImage.h"
#import "MTLJSONAdapter.h"

@implementation BRCCampObject

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    NSDictionary *paths = [super JSONKeyPathsByPropertyKey];
    NSDictionary *campPaths = @{
        NSStringFromSelector(@selector(hometown)): @"hometown",
        NSStringFromSelector(@selector(landmark)): @"landmark",
        NSStringFromSelector(@selector(frontage)): @"location.frontage",
        NSStringFromSelector(@selector(intersection)): @"location.intersection",
        NSStringFromSelector(@selector(intersectionType)): @"location.intersection_type",
        NSStringFromSelector(@selector(dimensions)): @"location.dimensions",
        NSStringFromSelector(@selector(exactLocation)): @"location.exact_location",
        NSStringFromSelector(@selector(images)): @"images"
    };
    return [paths mtl_dictionaryByAddingEntriesFromDictionary:campPaths];
}

+ (NSValueTransformer *)imagesJSONTransformer {
    return [MTLJSONAdapter arrayTransformerWithModelClass:BRCCampImage.class];
}

- (BRCObjectMetadata*) metadataWithTransaction:(YapDatabaseReadTransaction*)transaction {
    return [self campMetadataWithTransaction:transaction];
}

- (BRCCampMetadata*) campMetadataWithTransaction:(YapDatabaseReadTransaction*)transaction {
    id metadata = [transaction metadataForKey:self.yapKey inCollection:self.yapCollection];
    if ([metadata isKindOfClass:BRCCampMetadata.class]) {
        return metadata;
    }
    return [BRCCampMetadata new];
}
@end
