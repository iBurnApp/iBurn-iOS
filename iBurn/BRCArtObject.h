//
//  BRCArtObject.h
//  iBurn
//
//  Created by Christopher Ballinger on 7/28/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCDataObject.h"
#import "BRCArtImage.h"

NS_ASSUME_NONNULL_BEGIN
@interface BRCArtObject : BRCDataObject <BRCThumbnailProtocol>

@property (nonatomic, copy, readonly) NSString *artistName;
@property (nonatomic, copy, readonly) NSString *artistLocation;

@property (nonatomic, copy, readonly, nullable) NSString *category;
@property (nonatomic, copy, readonly, nullable) NSString *program;
@property (nonatomic, strong, readonly, nullable) NSURL *donationLink;
@property (nonatomic, readonly) BOOL guidedTours;
@property (nonatomic, readonly) BOOL selfGuidedTourMap;

/** use thumbnail_url key in dict */
@property (nonatomic, copy, readonly, nullable) NSArray<BRCArtImage*> *images;
/** Returns local URL if present, otherwise remote */
@property (nonatomic, strong, readonly, nullable) NSURL *thumbnailURL;
@property (nonatomic, strong, readonly, nullable) NSURL *remoteThumbnailURL;
@property (nonatomic, strong, readonly, nullable) NSURL *localThumbnailURL;

/** Returns local URL if present, otherwise remote */
@property (nonatomic, strong, readonly, nullable) NSURL *audioURL;
/** Remote audio tour URL - Note: Not directly mapped from new API spec */
@property (nonatomic, strong, readonly, nullable) NSURL *remoteAudioURL;
/** If cached, returns local URL otherwise nil */
@property (nonatomic, strong, readonly, nullable) NSURL *localAudioURL;

- (BRCArtMetadata*) artMetadataWithTransaction:(YapDatabaseReadTransaction*)transaction;

/**
 * Creates a special BRCArtObject for the audio tour introduction.
 * This object has uniqueID "intro" and will return the intro.m4a file as its audio URL.
 */
+ (nullable instancetype)introObject;

@end
NS_ASSUME_NONNULL_END
