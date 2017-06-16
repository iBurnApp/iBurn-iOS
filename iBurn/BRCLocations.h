//
//  BRCLocations.h
//  iBurn
//
//  Created by David Chiles on 8/4/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

NS_ASSUME_NONNULL_BEGIN
@interface BRCLocations : NSObject

/** location of the man in 2015 */
@property (nonatomic, class, readonly) CLLocationCoordinate2D blackRockCityCenter;

/** Within 5 miles of the man */
@property (nonatomic, class, readonly) CLCircularRegion  *burningManRegion;

@end
NS_ASSUME_NONNULL_END
