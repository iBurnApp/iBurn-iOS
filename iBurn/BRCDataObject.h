//
//  BRCDataObject.h
//  iBurn
//
//  Created by Christopher Ballinger on 7/28/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "MTLModel.h"
#import <CoreLocation/CoreLocation.h>

@interface BRCDataObject : MTLModel


@property (nonatomic, strong, readonly) NSString *title;
@property (nonatomic, strong, readonly) NSString *detailDescription;
@property (nonatomic, strong, readonly) NSString *email;
@property (nonatomic, strong, readonly) NSURL *url;

/**
 *  Real GPS coordinate
 */
@property (nonatomic, readonly) CLLocationCoordinate2D coordinate;


/**
 *  Unique 'id' from PlayaEvents API
 */
@property (nonatomic, strong, readonly) NSString *uniqueID;

/**
 *  Year of data's origin e.g. "2014"
 */
@property (nonatomic, strong, readonly) NSString *year;

/**
 *  Playa Coordinates
 */
@property (nonatomic, strong, readonly) NSNumber *playaHour;
@property (nonatomic, strong, readonly) NSNumber *playaMinute;
@property (nonatomic, strong, readonly) NSString *playaStreet;

@end
