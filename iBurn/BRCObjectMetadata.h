//
//  BRCObjectMetadata.h
//  iBurn
//
//  Created by Chris Ballinger on 8/7/17.
//  Copyright © 2017 Burning Man Earth. All rights reserved.
//

@import Mantle;
@import YapDatabase;
#import "BRCImageColors.h"

@class BRCObjectMetadata;
NS_ASSUME_NONNULL_BEGIN

@protocol BRCMetadataProtocol
@required
/** Returns object's metadata, or creates empty placeholder if not found. */
- (BRCObjectMetadata*) metadataWithTransaction:(YapDatabaseReadTransaction*)transaction;
- (void) replaceMetadata:(nullable BRCObjectMetadata*)metadata transaction:(YapDatabaseReadWriteTransaction*)transaction;
- (void) touchMetadataWithTransaction:(YapDatabaseReadWriteTransaction*)transaction;
@end

@interface BRCObjectMetadata : MTLModel
/**
 *  Whether or not user has favorited this object in the app.
 */
@property (nonatomic, readwrite) BOOL isFavorite;
/** Any notes added by the user */
@property (nonatomic, strong, nullable, readwrite) NSString *userNotes;
/** The last time object was fetched from iBurn API */
@property (nonatomic, strong, nullable, readwrite) NSDate *lastUpdated;

- (instancetype) metadataCopy;
@end

@interface BRCCampMetadata : BRCObjectMetadata
@end

@interface BRCEventMetadata : BRCObjectMetadata
/** EKEvent calendar eventIdentifier to be used when unsetting isFavorite */
@property (nonatomic, strong, readwrite, nullable) NSString *calendarEventIdentifier;
@end

@interface BRCArtMetadata : BRCObjectMetadata
/** Cached image colors from thumbnail */
@property (nonatomic, strong, readwrite, nullable) BRCImageColors *thumbnailImageColors;
@end


NS_ASSUME_NONNULL_END
