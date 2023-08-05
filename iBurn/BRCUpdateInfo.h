//
//  BRCUpdateInfo.h
//  iBurn
//
//  Created by Christopher Ballinger on 6/28/15.
//  Copyright (c) 2015 Burning Man Earth. All rights reserved.
//

#import <Mantle/Mantle.h>
#import "BRCDataObject.h"
#import "BRCYapDatabaseObject.h"

typedef NS_ENUM(NSUInteger, BRCUpdateDataType) {
    BRCUpdateDataTypeUnknown,
    BRCUpdateDataTypeArt,
    BRCUpdateDataTypeCamps,
    BRCUpdateDataTypeEvents,
    BRCUpdateDataTypeTiles,
    BRCUpdateDataTypePoints
};

typedef NS_ENUM(NSUInteger, BRCUpdateFetchStatus) {
    BRCUpdateFetchStatusUnknown,
    BRCUpdateFetchStatusFetching,
    BRCUpdateFetchStatusFailed,
    BRCUpdateFetchStatusComplete
};

NS_ASSUME_NONNULL_BEGIN
/** Metadata parsed from update.json */
@interface BRCUpdateInfo : BRCYapDatabaseObject <MTLJSONSerializing>

/// This can be a remote URL or a relative path file name
@property (nonatomic, strong, readonly) NSString *fileName;
/// When it was last updated on the server itself
@property (nonatomic, strong, readonly) NSDate *lastUpdated;
@property (nonatomic) BRCUpdateDataType dataType;
@property (nonatomic) BRCUpdateFetchStatus fetchStatus;
/// when we last checked update.json
@property (nonatomic, strong, nullable) NSDate *lastCheckedDate;
/// when we last fetched from the server
@property (nonatomic, strong, nullable) NSDate *fetchDate;
/// When the data was last succesfully loaded into the app
@property (nonatomic, strong, nullable) NSDate *ingestionDate;


/** Returns MTLModel subclass for dataType. Not valid for
 * tiles of course. */
- (nullable Class) dataObjectClass;

/** Converts from updates.json keys */
+ (BRCUpdateDataType) dataTypeFromString:(NSString*)dataTypeString;
+ (BRCUpdateDataType) dataTypeForClass:(Class)dataObjectClass;
+ (nullable NSString*) stringFromDataType:(BRCUpdateDataType)dataType;

/** Return yapKey for a subclass of BRCDataObject */
+ (nullable NSString*) yapKeyForClass:(Class)dataObjectClass;
+ (nullable NSString*) yapKeyForDataType:(BRCUpdateDataType)dataType;

@end
NS_ASSUME_NONNULL_END
