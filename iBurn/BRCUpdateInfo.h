//
//  BRCUpdateInfo.h
//  iBurn
//
//  Created by Christopher Ballinger on 6/28/15.
//  Copyright (c) 2015 Burning Man Earth. All rights reserved.
//

#import <Mantle/Mantle.h>

typedef NS_ENUM(NSUInteger, BRCUpdateDataType) {
    BRCUpdateDataTypeUnknown,
    BRCUpdateDataTypeArt,
    BRCUpdateDataTypeCamps,
    BRCUpdateDataTypeEvents,
    BRCUpdateDataTypeTiles
};

typedef NS_ENUM(NSUInteger, BRCUpdateFetchStatus) {
    BRCUpdateFetchStatusUnknown,
    BRCUpdateFetchStatusFetching,
    BRCUpdateFetchStatusFailed,
    BRCUpdateFetchStatusComplete
};

/** Metadata parsed from update.json */
@interface BRCUpdateInfo : MTLModel <MTLJSONSerializing>

@property (nonatomic, strong, readonly) NSString *fileName;
@property (nonatomic, strong, readonly) NSDate *lastUpdated;
@property (nonatomic) BRCUpdateDataType dataType;
@property (nonatomic) BRCUpdateFetchStatus fetchStatus;

/** Returns BRCDataObject subclass for dataType. Not valid for
 * tiles of course. */
- (Class) dataObjectClass;

- (NSString*) yapKey;

/**
 *  The YapDatabase collection of this class
 *
 *  @return collection for this class
 */
+ (NSString*) yapCollection;

/** Converts from updates.json keys */
+ (BRCUpdateDataType) dataTypeFromString:(NSString*)dataTypeString;
+ (BRCUpdateDataType) dataTypeForClass:(Class)dataObjectClass;
+ (NSString*) stringFromDataType:(BRCUpdateDataType)dataType;

/** Return yapKey for a subclass of BRCDataObject */
+ (NSString*) yapKeyForClass:(Class)dataObjectClass;
+ (NSString*) yapKeyForDataType:(BRCUpdateDataType)dataType;

@end
