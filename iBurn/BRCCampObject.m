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
#import "iBurn-Swift.h"

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

- (NSURL*) remoteThumbnailURL {
    BRCCampImage *firstImage = self.images.firstObject;
    if (![firstImage isKindOfClass:BRCCampImage.class]) {
        return nil;
    }
    return firstImage.thumbnailURL;
}

- (NSURL*) localThumbnailURL {
    return [self localMediaURLForType:BRCMediaDownloadTypeImage];
}

- (NSURL*) thumbnailURL {
    NSURL *localURL = self.localThumbnailURL;
    if (localURL) {
        return localURL;
    }
    return self.remoteThumbnailURL;
}

- (NSURL*) localMediaURLForType:(BRCMediaDownloadType)type {
    NSString *fileName = [BRCMediaDownloader fileName:self type:type];
    NSURL *url = [BRCMediaDownloader localMediaURL:fileName];
    if ([[NSFileManager defaultManager] fileExistsAtPath:url.path]) {
        return url;
    }
    return nil;
}

- (NSURL*) remoteMediaURLForType:(BRCMediaDownloadType)type {
    if (type == BRCMediaDownloadTypeImage) {
        return self.remoteThumbnailURL;
    }
    return nil;
}

@end
