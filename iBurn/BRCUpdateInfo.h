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

/** Metadata parsed from update.json */
@interface BRCUpdateInfo : MTLModel <MTLJSONSerializing>

@property (nonatomic, strong, readonly) NSString *fileName;
@property (nonatomic, strong, readonly) NSDate *lastUpdated;
@property (nonatomic) BRCUpdateDataType dataType;

/** Returns BRCDataObject subclass for dataType. Not valid for
 * tiles of course. */
- (Class) dataObjectClass;

/**
 *  The YapDatabase collection of this class
 *
 *  @return collection for this class
 */
+ (NSString*) yapCollection;

/** Converts from updates.json keys */
+ (BRCUpdateDataType) dataTypeFromString:(NSString*)dataTypeString;

@end
