//
//  BRCDataObject.h
//  iBurn
//
//  Created by Christopher Ballinger on 7/28/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import <Mantle/Mantle.h>
@import CoreLocation;
@import Mapbox;
@import YapDatabase;

NS_ASSUME_NONNULL_BEGIN
@protocol BRCYapDatabaseObjectProtocol <NSObject, NSCoding, NSCopying>
@required
/**
 * Unique YapDatabase key for this object.
 */
@property (nonatomic, readonly) NSString *yapKey;
/**
 *  The YapDatabase collection of this class
 *
 *  @return collection for this class
 */
@property (nonatomic, class, readonly) NSString *yapCollection;

- (void)touchWithTransaction:(YapDatabaseReadWriteTransaction *)transaction;
- (void)saveWithTransaction:(YapDatabaseReadWriteTransaction *)transaction;
- (void)removeWithTransaction:(YapDatabaseReadWriteTransaction *)transaction;
/** This will fetch an updated (copied) instance of the object. If nil, it means it was deleted or not present in the db. */
- (nullable instancetype)refetchWithTransaction:(YapDatabaseReadTransaction *)transaction;

+ (nullable instancetype)fetchObjectWithYapKey:(NSString*)yapKey transaction:(YapDatabaseReadTransaction*)transaction;
@end

@interface BRCDataObject : MTLModel <MTLJSONSerializing, MGLAnnotation, BRCYapDatabaseObjectProtocol>

#pragma mark Mutable Properties

/**
 *  Whether or not user has favorited this object in the app.
 */
@property (nonatomic, readwrite) BOOL isFavorite;

/** Any notes added by the user */
@property (nonatomic, strong) NSString *userNotes;

/** The last time object was fetched from iBurn API */
@property (nonatomic, strong, readwrite) NSDate *lastUpdated;

#pragma mark Constant Properties

/**
 *  Object title (from the PlayaEvents API)
 */
@property (nonatomic, copy, readonly) NSString *title;
/**
 *  Object description (from the PlayaEvents API)
 */
@property (nonatomic, strong, readonly) NSString *detailDescription;
/**
 *  Email (from the PlayaEvents API)
 */
@property (nonatomic, strong, readonly) NSString *email;

/**
 *  Homepage (from the PlayaEvents API)
 */
@property (nonatomic, strong, readonly) NSURL *url;

/**
 *  Real GPS location (this property is dynamically generated)
 */
@property (nonatomic, readonly) CLLocation *location;

/** Same as location (this property is dynamically generated) */
@property (nonatomic, readwrite) CLLocationCoordinate2D coordinate;

/**
 *  Unique 'id' from PlayaEvents API
 */
@property (nonatomic, strong, readonly) NSString *uniqueID;

/**
 *  Year of data's origin e.g. "2014"
 */
@property (nonatomic, strong, readonly) NSNumber *year;

/**
 *  Playa Coordinates
 */
@property (nonatomic, strong) NSString *playaLocation;

/** Calculates distance from location */
- (CLLocationDistance) distanceFromLocation:(CLLocation*)location;

@end

@interface BRCDataObject (MarkerImage)
@property (nonatomic, strong, readonly) UIImage *brc_markerImage;
@end
NS_ASSUME_NONNULL_END
