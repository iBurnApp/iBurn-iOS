//
//  BRCDataObject.h
//  iBurn
//
//  Created by Christopher Ballinger on 7/28/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "MTLModel.h"
#import "MTLJSONAdapter.h"
#import <CoreLocation/CoreLocation.h>

@interface BRCDataObject : MTLModel <MTLJSONSerializing>

#pragma mark Mutable Properties

/**
 *  Whether or not user has favorited this object in the app.
 */
@property (nonatomic, readwrite) BOOL isFavorite;

#pragma mark Constant Properties

/**
 *  All of the below properties are from the PlayaEvents API
 */

@property (nonatomic, strong, readonly) NSString *title;
@property (nonatomic, strong, readonly) NSString *detailDescription;
@property (nonatomic, strong, readonly) NSString *email;
@property (nonatomic, strong, readonly) NSURL *url;

/**
 *  Real GPS location (this property is dynamically generated)
 */
@property (nonatomic, readonly) CLLocation *location;

/**
 *  Unique 'id' from PlayaEvents API
 */
@property (nonatomic, strong, readonly) NSString *uniqueID;

/**
 *  Year of data's origin e.g. "2014"
 */
@property (nonatomic, strong, readonly) NSString *year;

/**
 *  Playa Coordinates - currently unused
 */
@property (nonatomic, strong, readonly) NSString *playaLocation;

/**
 *  The YapDatabase collection of this class
 *
 *  @return collection for this class
 */
+ (NSString*) collection;

@end
