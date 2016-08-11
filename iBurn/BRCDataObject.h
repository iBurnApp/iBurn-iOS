//
//  BRCDataObject.h
//  iBurn
//
//  Created by Christopher Ballinger on 7/28/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import <Mantle/Mantle.h>
@import CoreLocation;

@interface BRCDataObject : MTLModel <MTLJSONSerializing>

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
@property (nonatomic, strong, readonly) NSString *title;
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

/**
 *  The YapDatabase collection of this class
 *
 *  @return collection for this class
 */
+ (NSString*) collection;



@end
