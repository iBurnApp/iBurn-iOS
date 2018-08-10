//
//  BRCArtObject.m
//  iBurn
//
//  Created by Christopher Ballinger on 7/28/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCArtObject.h"
#import "NSDictionary+MTLManipulationAdditions.h"
#import "NSValueTransformer+MTLPredefinedTransformerAdditions.h"
#import "iBurn-Swift.h"

@implementation BRCArtObject

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    NSDictionary *paths = [super JSONKeyPathsByPropertyKey];
    NSDictionary *artPaths = @{NSStringFromSelector(@selector(artistName)): @"artist",
             NSStringFromSelector(@selector(artistLocation)): @"hometown",
             NSStringFromSelector(@selector(imageURLs)): @"images",
                               NSStringFromSelector(@selector(remoteAudioURL)): @"audio_tour_url"};
    return [paths mtl_dictionaryByAddingEntriesFromDictionary:artPaths];
}

+ (NSValueTransformer *)remoteAudioURLJSONTransformer {
    return [NSValueTransformer valueTransformerForName:MTLURLValueTransformerName];
}

/*
 "images": [
    {
        "gallery_ref": 82828,
        "thumbnail_url": "http://galleries.burningman.org/include/../filestore/tmp/api_resource_cache/82828_bbe3408f7c71e6bcc6dc11bb9c5e3695.jpg"
    }
],
 */

- (NSURL*) remoteThumbnailURL {
    NSString *urlString = self.imageURLs.firstObject[@"thumbnail_url"];
    if (![urlString isKindOfClass:NSString.class]) {
        return nil;
    }
    return [NSURL URLWithString:urlString];
}

- (NSURL*) localThumbnailURL {
    return [self localMediaURLForType:BRCMediaDownloadTypeImage];
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
    if (type == BRCMediaDownloadTypeAudio) {
        return self.remoteAudioURL;
    } else if (type == BRCMediaDownloadTypeImage) {
        return self.remoteThumbnailURL;
    }
    return nil;
}

- (NSURL*) thumbnailURL {
    if (self.localThumbnailURL) {
        return self.localThumbnailURL;
    } else {
        return self.remoteThumbnailURL;
    }
}

- (NSURL*) audioURL {
    if (self.localAudioURL) {
        return self.localAudioURL;
    } else {
        return self.remoteAudioURL;
    }
}

- (NSURL*) localAudioURL {
    return [self localMediaURLForType:BRCMediaDownloadTypeAudio];
}

- (BRCObjectMetadata*) metadataWithTransaction:(YapDatabaseReadTransaction*)transaction {
    return [self artMetadataWithTransaction:transaction];
}

- (BRCArtMetadata*) artMetadataWithTransaction:(YapDatabaseReadTransaction*)transaction {
    id metadata = [transaction metadataForKey:self.yapKey inCollection:self.yapCollection];
    if ([metadata isKindOfClass:BRCArtMetadata.class]) {
        return metadata;
    }
    return [BRCArtMetadata new];
}

@end
