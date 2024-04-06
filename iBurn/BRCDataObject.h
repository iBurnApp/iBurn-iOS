//
//  BRCDataObject.h
//  iBurn
//
//  Created by Christopher Ballinger on 7/28/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

@import Mantle;
@import CoreLocation;
@import MapLibre;
@import YapDatabase;
#import "BRCYapDatabaseObject.h"
#import "BRCObjectMetadata.h"

NS_ASSUME_NONNULL_BEGIN

@interface BRCDataObject : BRCYapDatabaseObject <MTLJSONSerializing, BRCMetadataProtocol>

#pragma mark Constant Properties

/**
 *  Object title (from the PlayaEvents API)
 */
@property (nonatomic, copy, readonly) NSString *title;
/**
 *  Object description (from the PlayaEvents API)
 */
@property (nonatomic, strong, readonly, nullable) NSString *detailDescription;
/**
 *  Email (from the PlayaEvents API)
 */
@property (nonatomic, strong, readonly, nullable) NSString *email;

/**
 *  Homepage (from the PlayaEvents API)
 */
@property (nonatomic, strong, readonly, nullable) NSURL *url;

/**
 *  Real GPS location (this property is dynamically generated)
 */
@property (nonatomic, readonly, nullable) CLLocation *location;

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
@property (nonatomic, strong, nullable) NSString *playaLocation;

/** Calculates distance from location */
- (CLLocationDistance) distanceFromLocation:(CLLocation*)location;

// MARK: Burner Map

/**
 *  Real GPS location (this property is dynamically generated)
 */
@property (nonatomic, readonly, nullable) CLLocation *burnerMapLocation;

/** Same as location (this property is dynamically generated) */
@property (nonatomic, readwrite) CLLocationCoordinate2D burnerMapCoordinate;

/**
 *  Playa Coordinates e.g. 7:30 & Inspirit
 */
@property (nonatomic, readwrite, nullable) NSString *burnerMapLocationString;

@end

@interface BRCDataObject (MarkerImage)
@property (nonatomic, strong, readonly) UIImage *brc_markerImage;
@end
NS_ASSUME_NONNULL_END
