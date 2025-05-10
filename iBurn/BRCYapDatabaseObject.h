//
//  BRCYapDatabaseObject.h
//  iBurn
//
//  Created by Chris Ballinger on 6/19/17.
//  Copyright © 2017 Burning Man Earth. All rights reserved.
//

@import Foundation;
@import YapDatabase;
@import Mantle;

NS_ASSUME_NONNULL_BEGIN
@protocol BRCYapDatabaseObjectProtocol
@required

/**
 * Unique YapDatabase key for this object.
 */
@property (nonatomic, copy, readonly) NSString *yapKey;

/**
 *  The YapDatabase collection of this object
 *
 *  @return collection for this object
 */
@property (nonatomic, copy, readonly) NSString *yapCollection;

/**
 *  The YapDatabase collection of this class
 *
 *  @return collection for this class
 */
@property (nonatomic, copy, class, readonly) NSString *yapCollection;

/** Whether or not an object with this key/collection exists in the database */
- (BOOL)existsWithTransaction:(YapDatabaseReadTransaction*)transaction;
- (void)touchWithTransaction:(YapDatabaseReadWriteTransaction *)transaction;
- (void)saveWithTransaction:(YapDatabaseReadWriteTransaction *)transaction metadata:(nullable id)metadata;
/** Checks if object exists before saving. If metadata is nil, it will not overwrite existing metadata. */
- (void)upsertWithTransaction:(YapDatabaseReadWriteTransaction *)transaction metadata:(nullable id)metadata;
/** Replaces just the object, and doesn't touch the metadata */
- (void)replaceWithTransaction:(YapDatabaseReadWriteTransaction *)transaction;
- (void)removeWithTransaction:(YapDatabaseReadWriteTransaction *)transaction;
/** This will fetch an updated (copied) instance of the object. If nil, it means it was deleted or not present in the db. */
- (nullable instancetype)refetchWithTransaction:(YapDatabaseReadTransaction *)transaction;

+ (nullable id<BRCYapDatabaseObjectProtocol>)fetchWithYapKey:(NSString*)yapKey transaction:(YapDatabaseReadTransaction*)transaction;
@end

@interface BRCYapDatabaseObject : MTLModel <BRCYapDatabaseObjectProtocol>

/** Passing nil yapKey will result in a randomly generated UUID */
- (instancetype) initWithYapKey:(nullable NSString*)yapKey;

/** Debug description for this object */
@property (nonatomic, copy, readonly) NSString *debugDescription;

@end
NS_ASSUME_NONNULL_END
