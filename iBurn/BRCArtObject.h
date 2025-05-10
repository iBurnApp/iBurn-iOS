//
//  BRCArtObject.h
//  iBurn
//
//  Created by Christopher Ballinger on 7/28/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCDataObject.h"

NS_ASSUME_NONNULL_BEGIN
@interface BRCArtObject : BRCDataObject

@property (nonatomic, copy, readonly) NSString *artistName;
@property (nonatomic, copy, readonly) NSString *artistLocation;

/** use thumbnail_url key in dict */
@property (nonatomic, copy, readonly) NSArray<NSDictionary*> *imageURLs;
/** Returns local URL if present, otherwise remote */
@property (nonatomic, strong, readonly, nullable) NSURL *thumbnailURL;
@property (nonatomic, strong, readonly, nullable) NSURL *remoteThumbnailURL;
@property (nonatomic, strong, readonly, nullable) NSURL *localThumbnailURL;

/** Returns local URL if present, otherwise remote */
@property (nonatomic, strong, readonly, nullable) NSURL *audioURL;
/** Remote audio tour URL */
@property (nonatomic, strong, readonly, nullable) NSURL *remoteAudioURL;
/** If cached, returns local URL otherwise nil */
@property (nonatomic, strong, readonly, nullable) NSURL *localAudioURL;

- (BRCArtMetadata*) artMetadataWithTransaction:(YapDatabaseReadTransaction*)transaction;

@end
NS_ASSUME_NONNULL_END
